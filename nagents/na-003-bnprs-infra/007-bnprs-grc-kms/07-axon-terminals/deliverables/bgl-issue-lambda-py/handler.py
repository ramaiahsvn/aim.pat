# bgl-issue — AWS Lambda (Python 3.12, arm64) signing endpoint for BGL license tokens.
# na-003/007 grc-kms.  POST /bgl/v1/issue (API GW 8nlf3cfyd9, execute-api endpoint, bearer auth).
#
# Pure-Python Ed25519 (RFC 8032 reference) + hashlib SHA-512 — NO native deps, zips as one file.
# boto3 is built into the Lambda runtime. Reads the kid=3 signing key + bearer token from Secrets
# Manager (envelope-encrypted by alias/bnprs-bgl-signing-prod); logs every lid to DynamoDB.
# Produces the fixed big-endian claim block from bgl/BGL-TOKEN-SPEC.md so bgl_verify accepts it.

import base64, hashlib, json, os, struct, time, uuid, hmac
import boto3

KID = 3
ALLOWED_PRODUCTS = {3}
SIGNING_SECRET = "bgl-signing-key"
BEARER_SECRET  = "bgl-enroll-token"
LOG_TABLE      = "bgl-issuance-log"

_sm = boto3.client("secretsmanager")
_ddb = boto3.client("dynamodb")
_cache = {}

# ---- Ed25519 (RFC 8032 reference implementation; deterministic) ----
_q = 2**255 - 19
_L = 2**252 + 27742317777372353535851937790883648493
def _H(m): return hashlib.sha512(m).digest()
def _inv(x): return pow(x, _q - 2, _q)
_d = -121665 * _inv(121666) % _q
_I = pow(2, (_q - 1) // 4, _q)
def _xrecover(y):
    xx = (y*y - 1) * _inv(_d*y*y + 1)
    x = pow(xx, (_q + 3) // 8, _q)
    if (x*x - xx) % _q != 0: x = (x * _I) % _q
    if x % 2 != 0: x = _q - x
    return x
_By = 4 * _inv(5) % _q
_B = [_xrecover(_By) % _q, _By % _q]
def _edwards(P, Q):
    x1, y1 = P; x2, y2 = Q
    x3 = (x1*y2 + x2*y1) * _inv(1 + _d*x1*x2*y1*y2) % _q
    y3 = (y1*y2 + x1*x2) * _inv(1 - _d*x1*x2*y1*y2) % _q
    return [x3 % _q, y3 % _q]
def _scalarmult(P, e):
    if e == 0: return [0, 1]
    Q = _scalarmult(P, e // 2); Q = _edwards(Q, Q)
    if e & 1: Q = _edwards(Q, P)
    return Q
def _encodeint(y): return y.to_bytes(32, "little")
def _encodepoint(P):
    x, y = P
    bits = [(y >> i) & 1 for i in range(255)] + [x & 1]
    return bytes(sum(bits[i*8 + j] << j for j in range(8)) for i in range(32))
def _bit(h, i): return (h[i // 8] >> (i % 8)) & 1
def _Hint(m):
    h = _H(m); return sum(2**i * _bit(h, i) for i in range(512))
def ed25519_sign(msg, seed32, pub32):
    h = _H(seed32)
    a = 2**254 + sum(2**i * _bit(h, i) for i in range(3, 254))
    r = _Hint(h[32:64] + msg)
    R = _scalarmult(_B, r)
    S = (r + _Hint(_encodepoint(R) + pub32 + msg) * a) % _L
    return _encodepoint(R) + _encodeint(S)

# ---- helpers ----
def _b64url(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def _secret_bytes(name):
    if name not in _cache:
        r = _sm.get_secret_value(SecretId=name)
        _cache[name] = r["SecretBinary"] if "SecretBinary" in r else r["SecretString"].encode()
    return _cache[name]

def _resp(status, obj):
    return {"statusCode": status, "headers": {"content-type": "application/json"}, "body": json.dumps(obj)}

def _build_block(products, plat_mask, feat, iat, nbf, exp, lid, bid):
    b = bytearray(b"BGL1")
    b += bytes([1, 1, plat_mask, len(products)])        # ver, bind=hwid, plat, nproducts
    b += struct.pack(">I", feat)
    b += struct.pack(">Q", iat) + struct.pack(">Q", nbf) + struct.pack(">Q", exp)
    b += lid                                            # 16
    b += struct.pack(">H", KID)
    b += bid                                            # 32
    b += bytes(products)
    return bytes(b)

def handler(event, context):
    # bearer auth (sole forge gate; execute-api endpoint, no mTLS)
    hdrs = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    presented = (hdrs.get("authorization") or "").removeprefix("Bearer ").strip()
    expected = _secret_bytes(BEARER_SECRET).decode().strip()
    if not presented or not hmac.compare_digest(presented, expected):
        return _resp(401, {"error": "unauthorized", "message": "invalid or missing bearer token"})

    try:
        body = json.loads(event.get("body") or "{}")
    except Exception:
        return _resp(400, {"error": "bad_request", "message": "invalid json"})

    products = [int(p) for p in body.get("product_ids", [])]
    if not products or any(p not in ALLOWED_PRODUCTS for p in products):
        return _resp(403, {"error": "policy_denied", "message": "product not allowed"})
    bid_hex = body.get("bid", "")
    try:
        bid = bytes.fromhex(bid_hex)
        assert len(bid) == 32
    except Exception:
        return _resp(400, {"error": "bad_request", "message": "bid must be 64 hex chars"})
    plat_mask = int(body.get("plat_mask", 0)) & 0xFF
    feat = int(body.get("feat", 0)) & 0xFFFFFFFF
    exp_days = int(body.get("exp_days", 0))

    now = int(time.time())
    exp = now + exp_days * 86400 if exp_days > 0 else 0   # 0 = perpetual (owner-approved)
    lid = uuid.uuid4().bytes

    block = _build_block(products, plat_mask, feat, now, 0, exp, lid, bid)
    key = _secret_bytes(SIGNING_SECRET)                  # 64B seed||pub
    sig = ed25519_sign(block, key[:32], key[32:64])
    token = "BGL1." + _b64url(block) + "." + _b64url(sig)

    lid_hex = lid.hex()
    try:
        _ddb.put_item(TableName=LOG_TABLE, Item={
            "lid": {"S": lid_hex}, "bid": {"S": bid_hex},
            "products": {"S": json.dumps(products)}, "plat_mask": {"N": str(plat_mask)},
            "kid": {"N": str(KID)}, "iat": {"N": str(now)}, "requester": {"S": "bearer"},
        })
    except Exception:
        pass  # log best-effort; tighten to fail-closed if required

    return _resp(200, {"bgl_lic": 1, "token": token, "kid": KID, "lid": lid_hex})
