# HANDOFF → na-003/007 bnprs-grc-kms

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Priority:** normal · **Status:** OPEN

## Ask (one line)
Stand up an **offline-token signing API** — `POST /bgl/v1/issue` — that signs BGL license tokens
with a grc-kms-custodied **Ed25519** key and logs every issuance. This is the issuance backend for
BprCardQi fleet auto-licensing; the workstation enrollment exe and the lib-side verify/load are
already built (na-003/011).

**Canonical spec (read this):**
`aim.pat/nagents/na-003-bnprs-infra/011-bnprs-lib-license/07-axon-terminals/deliverables/design/fleet-enrollment-and-issuance-api.md`
**Signing code to wrap:** `bpr.cpp/src/AprCommon/BprLicense/bgl/` — `bgl_claims_encode()` +
`bgl_sign()` (declared in `bgl_internal.h`); token assembly `bgl_token_build()`.

---

## ⚠️ Key-custody decision you must make first (Ed25519 vs AWS KMS)

BGL tokens are **Ed25519** (TweetNaCl) — the public key is compiled into every shipped lib
(`bgl_pubkeys.h`), so **the signature algorithm cannot change** without re-shipping all libs.
**AWS KMS does not support Ed25519 signing** (only ECC_NIST P-256/384/521 + SECG_P256K1). So you
cannot do the sign operation inside KMS directly. Two viable custody models — pick one:

- **(A — recommended) Generate a NEW Ed25519 keypair in grc-kms custody (next kid, e.g. kid=3).**
  Store the 64-byte secret **envelope-encrypted under an AWS KMS data key** (KMS protects it at
  rest; the signing service decrypts it in-memory only to sign, never logs/persists plaintext).
  Hand the **public key** to na-003/011 → we embed it in `bgl_pubkeys.h` and retire kid=2 → the
  fleet DLL rebuild (na-005/002 cpp-card-qi) ships the new kid. No private key is ever exported from
  where it's generated. **Ordering:** grc-kms gens kid → gives pubkey → 011 embeds → cpp-card-qi
  builds → enrollment issues. (No real licenses have been issued yet, so rotating the kid now is free.)
- **(B — only if you must reuse kid=2)** Import the existing kid=2 secret (currently self-managed by
  na-003/011: encrypted backup + macOS Keychain) into grc-kms custody. Avoids a re-embed/rebuild but
  requires moving an existing private key — generally discouraged. Coordinate with 011 if chosen.

Either way: **the Ed25519 private key never lives in the exe or the lib, and is never logged.**

---

## API contract

```
POST /bgl/v1/issue
Authorization: <enrollment credential — see Security>
Content-Type: application/json

Request body (.req):
{
  "bgl_req": 1,
  "product_ids": [3],          // BprCardQi (product-codes.yaml product_id 3)
  "bind": "hwid",
  "bid": "<64-hex hwid>",       // already-hashed; raw machine ids never sent
  "plat_mask": 1,               // bit0 = Windows
  "exp_days": 0,                // 0 = perpetual (owner-approved for this fleet)
  "feat": 0,
  "station": { "hostname": "POS-0142", "note": "audit only, optional" }
}

200 OK:
{ "bgl_lic": 1, "token": "BGL1.<b64url block>.<b64url sig>", "kid": <n>, "lid": "<uuid>" }

4xx: { "error": "unauthorized|policy_denied|bad_request", "message": "..." }
```

## What the signer does per request
1. **AuthN/AuthZ** the caller (hard requirement — see Security).
2. **Validate against policy:** product_ids ⊆ allowed set (`[3]` for this fleet); `plat_mask`
   allowed; `bid` is 64-hex; honor `exp_days:0` only if perpetual is permitted for that requester.
3. **Build claims** (`bgl_claims`): set products, bind=1(hwid), bid, plat_mask, feat,
   iat=now, nbf=0, exp=0 (or now+exp_days·86400), fresh random **lid** (16B UUID), kid.
4. `bgl_claims_encode()` → fixed binary block; `bgl_sign(block, sk)` → 64-byte sig;
   `bgl_token_build()` → `BGL1.<...>.<...>`.
5. **Log issuance** `{lid, bid, product_ids, plat_mask, kid, requester, iat}` to the issuance log
   (NOT the key, NOT the token secret). This log is the revocation source of truth.
6. Return token + kid + lid.

### Claim block byte layout (big-endian, signed bytes) — from BGL-TOKEN-SPEC.md
| off | size | field | notes |
|----:|-----:|-------|-------|
| 0 | 4 | magic `BGL1` | |
| 4 | 1 | ver = 1 | |
| 5 | 1 | bind | 1 = hwid |
| 6 | 1 | plat_mask | 1 = win |
| 7 | 1 | nproducts | ≥1 |
| 8 | 4 | feat | |
| 12 | 8 | iat | unix s |
| 20 | 8 | nbf | 0 = none |
| 28 | 8 | exp | 0 = perpetual |
| 36 | 16 | lid | UUID bytes |
| 52 | 2 | kid | uint16 |
| 54 | 32 | bid | binding hash |
| 86 | N | products | N product_id bytes |

(You don't hand-assemble this — call `bgl_claims_encode()`. Layout shown for reference/validation.)

## Security requirements (hard)
1. **The endpoint is the only forge point.** Gate it: mTLS client cert per fleet, or short-lived
   enrollment secret + asset/IP allowlist + rate limiting. Anyone who can call it can mint a license.
2. **Perpetual ⇒ blocklist is the revocation path.** Because tokens never self-expire, log every
   `lid` so a signed offline **blocklist** can later be bundled with lib/public-key updates to kill a
   leaked/decommissioned license. (hwid-binding already limits a leaked token to one physical machine.)
3. Private key envelope-encrypted at rest (KMS data key); decrypted only in the signing process;
   never logged, never returned.

## Definition of done
- [ ] Custody decision (A or B) made; if A, kid + public key delivered to na-003/011.
- [ ] `POST /bgl/v1/issue` live, authenticated, policy-validated.
- [ ] Issuance log capturing `lid`/`bid`/requester per token.
- [ ] One end-to-end test: a real workstation `.req` → token → `bgl-inspect` shows signature VALID
      and the token activates BprCardQi on that machine.

## Coordination
- **na-003/011** (this agent): owns token format, claim-encode/sign code, lib verify+load, the
  enrollment exe; will embed the public key (option A) and reconcile `bgl_pubkeys.h`.
- **na-005/002 cpp-card-qi**: builds the BprCardQi DLL (with the new kid) + the enrollment exe.
- Reply / questions: leave a note in `na-003/011 .../07-axon-terminals/notifications/` or ping via BNA.
