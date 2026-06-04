// bgl-issue — AWS Lambda (Rust, arm64) signing endpoint for BGL license tokens.
// na-003/007 grc-kms.  STATUS: code only — NOT deployed (owner approval pending).
//
// POST /bgl/v1/issue  (behind API GW 8nlf3cfyd9, kms.bnprs.ai, mTLS fleet cert + WAF)
//   body  = enrollment .req JSON (see fleet-enrollment-and-issuance-api.md §3)
//   reply = { "bgl_lic":1, "token":"BGL1.<b64url block>.<b64url sig>", "kid":3, "lid":"<uuid>" }
//
// The Ed25519 secret (kid=3, 64B TweetNaCl seed||pub) is read from Secrets Manager
// (bgl-signing-key, envelope-encrypted by alias/bnprs-bgl-signing-prod) into memory only.
// Mirrors the fixed big-endian claim block in bgl/BGL-TOKEN-SPEC.md so the C verifier
// (bgl_verify) accepts the token unchanged.

use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use ed25519_dalek::{Signer, SigningKey};
use lambda_http::{run, service_fn, Body, Error, Request, Response};
use serde_json::Value;
use std::time::{SystemTime, UNIX_EPOCH};

const KID: u16 = 3;
const ALLOWED_PRODUCTS: &[u8] = &[3]; // BprCardQi fleet (extend per policy)

// ---- BGL claim block (big-endian; identical layout to bgl_claims_encode) ----
fn build_block(products: &[u8], plat_mask: u8, feat: u32, iat: u64, nbf: u64, exp: u64,
               lid: &[u8; 16], bid: &[u8; 32]) -> Vec<u8> {
    let mut b = Vec::with_capacity(86 + products.len());
    b.extend_from_slice(b"BGL1");          // 0  magic
    b.push(1);                             // 4  ver
    b.push(1);                             // 5  bind = hwid
    b.push(plat_mask);                     // 6  plat_mask
    b.push(products.len() as u8);          // 7  nproducts
    b.extend_from_slice(&feat.to_be_bytes());  // 8  feat u32
    b.extend_from_slice(&iat.to_be_bytes());   // 12 iat u64
    b.extend_from_slice(&nbf.to_be_bytes());   // 20 nbf u64
    b.extend_from_slice(&exp.to_be_bytes());   // 28 exp u64
    b.extend_from_slice(lid);              // 36 lid (16)
    b.extend_from_slice(&KID.to_be_bytes());   // 52 kid u16
    b.extend_from_slice(bid);              // 54 bid (32)
    b.extend_from_slice(products);         // 86 products
    b
}

fn err(status: u16, code: &str, msg: &str) -> Response<Body> {
    Response::builder().status(status).header("content-type", "application/json")
        .body(Body::from(format!("{{\"error\":\"{code}\",\"message\":\"{msg}\"}}"))).unwrap()
}

async fn load_signing_key() -> Result<[u8; 64], Error> {
    // Read the 64-byte Ed25519 secret (seed||pub) from Secrets Manager (binary secret).
    let cfg = aws_config::load_from_env().await;
    let sm = aws_sdk_secretsmanager::Client::new(&cfg);
    let out = sm.get_secret_value().secret_id("bgl-signing-key").send().await?;
    let blob = out.secret_binary().ok_or("secret_binary missing")?;
    let bytes = blob.as_ref();
    if bytes.len() != 64 { return Err("signing key must be 64 bytes".into()); }
    let mut k = [0u8; 64]; k.copy_from_slice(bytes); Ok(k)
}

async fn log_issuance(lid: &str, bid: &str, products: &[u8], plat: u8, requester: &str, iat: u64) {
    // Append to the issuance log (revocation source of truth for perpetual tokens).
    let cfg = aws_config::load_from_env().await;
    let ddb = aws_sdk_dynamodb::Client::new(&cfg);
    use aws_sdk_dynamodb::types::AttributeValue as A;
    let _ = ddb.put_item().table_name("bgl-issuance-log")
        .item("lid", A::S(lid.into()))
        .item("bid", A::S(bid.into()))
        .item("products", A::S(format!("{products:?}")))
        .item("plat_mask", A::N(plat.to_string()))
        .item("kid", A::N(KID.to_string()))
        .item("requester", A::S(requester.into()))
        .item("iat", A::N(iat.to_string()))
        .send().await; // best-effort; a hard requirement in prod (fail-closed on log error)
}

async fn handler(req: Request) -> Result<Response<Body>, Error> {
    // mTLS client identity is enforced at the API Gateway (fleet cert); the caller cert
    // subject is also available here via request context for finer authz if needed.
    let body = match std::str::from_utf8(req.body()) { Ok(s) => s, Err(_) => return Ok(err(400,"bad_request","non-utf8 body")) };
    let j: Value = match serde_json::from_str(body) { Ok(v) => v, Err(_) => return Ok(err(400,"bad_request","invalid json")) };

    // ---- parse + validate policy ----
    let products: Vec<u8> = j["product_ids"].as_array().map(|a|
        a.iter().filter_map(|v| v.as_u64().map(|n| n as u8)).collect()).unwrap_or_default();
    if products.is_empty() || !products.iter().all(|p| ALLOWED_PRODUCTS.contains(p)) {
        return Ok(err(403, "policy_denied", "product not allowed"));
    }
    let bid_hex = j["bid"].as_str().unwrap_or("");
    let bid_vec = match hex::decode(bid_hex) { Ok(v) if v.len()==32 => v, _ => return Ok(err(400,"bad_request","bid must be 64 hex chars")) };
    let mut bid = [0u8;32]; bid.copy_from_slice(&bid_vec);
    let plat_mask = j["plat_mask"].as_u64().unwrap_or(0) as u8;
    let feat = j["feat"].as_u64().unwrap_or(0) as u32;
    let exp_days = j["exp_days"].as_u64().unwrap_or(0);
    // Perpetual (exp_days==0) is owner-approved for this fleet; gate here if policy changes.

    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    let exp = if exp_days > 0 { now + exp_days * 86400 } else { 0 };
    let lid_uuid = uuid::Uuid::new_v4();
    let lid = *lid_uuid.as_bytes();

    // ---- build + sign ----
    let block = build_block(&products, plat_mask, feat, now, 0, exp, &lid, &bid);
    let key = load_signing_key().await?;
    let mut seed = [0u8;32]; seed.copy_from_slice(&key[..32]); // TweetNaCl secret = seed||pub
    let signing = SigningKey::from_bytes(&seed);
    let sig = signing.sign(&block);

    let token = format!("BGL1.{}.{}",
        URL_SAFE_NO_PAD.encode(&block),
        URL_SAFE_NO_PAD.encode(sig.to_bytes()));

    let lid_str = lid_uuid.simple().to_string();
    let requester = "mtls-fleet"; // refine from client-cert subject in request context
    log_issuance(&lid_str, bid_hex, &products, plat_mask, requester, now).await;

    Ok(Response::builder().status(200).header("content-type","application/json")
        .body(Body::from(format!(
            "{{\"bgl_lic\":1,\"token\":\"{token}\",\"kid\":{KID},\"lid\":\"{lid_str}\"}}"))).unwrap())
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    run(service_fn(handler)).await
}
