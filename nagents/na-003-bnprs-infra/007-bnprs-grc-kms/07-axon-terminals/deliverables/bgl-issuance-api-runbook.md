# BGL Issuance API — deployment runbook (na-003/007 grc-kms)

**Date:** 2026-06-04 · **Status:** DESIGN — production AWS provisioning PENDING owner approval
**Endpoint:** `POST https://kms.bnprs.ai/bgl/v1/issue` · **Account:** bnprs (891963159778) / ap-south-2

## Strategy: reuse the live k3-verifychallenge stack
`kms.bnprs.ai` already terminates at API Gateway HTTP API **`8nlf3cfyd9`** with **mTLS** (per-device
fleet cert `CN=bpr-cardqi-fleet`, valid to 2036-05-15), **WAF** (1 req/s, burst 5), and a Rust/arm64
Lambda pattern reading **Secrets Manager** decrypted by **KMS**. The BGL issuer is a *new route +
Lambda on the same stack* — the mTLS auth the na-003/011 handoff required is already in place.

## New resources to provision (each = gated AWS write → confirm before run)
| Resource | Proposed id | Purpose |
|---|---|---|
| KMS CMK | `alias/bnprs-bgl-signing-prod` (SYMMETRIC_DEFAULT, rotation on) | envelope-encrypt the signing secret |
| Secrets Manager | `bgl-signing-key` | holds the 64-byte Ed25519 secret (kid=3); decrypted into Lambda memory only |
| Lambda | `bgl-issue` (Rust, arm64, provided.al2023) | claims-encode + Ed25519 sign → BGL token |
| API GW route | `POST /bgl/v1/issue` on `8nlf3cfyd9` | reuses mTLS + WAF + `kms.bnprs.ai` domain |
| Issuance log | DynamoDB `bgl-issuance-log` (or CloudWatch) | one record per token: lid, bid, products, plat, kid, requester, iat |

## Lambda logic (port from bgl-issue)
Mirror `bpr.cpp/.../bgl/tools/bgl_issue.c`: build `bgl_claims` (products, bind=hwid, bid, plat_mask,
exp from policy, fresh lid, kid=3) → `bgl_claims_encode` (fixed BE block, see BGL-TOKEN-SPEC.md) →
Ed25519 sign (e.g. `ed25519-dalek`) over the block → `BGL1.<b64url block>.<b64url sig>`. Validate
request against policy (product∈allowed, plat allowed, exp_days:0 only if perpetual permitted), then
**append to the issuance log before returning** (log is the revocation source of truth).

## Key provisioning (one atomic gated step — generate→store→wipe)
The kid=3 key already exists in interim local custody (`~/BPR/.keys-backup/bgl/bgl-kid3.key.enc`,
Keychain `bgl-kid3-signing-key`). To migrate to AWS (after approval):
```
# decrypt locally, push to Secrets Manager (encrypted by the new CMK), then wipe the plaintext
aws kms create-key --profile bnprs --region ap-south-2 ...        # → alias/bnprs-bgl-signing-prod
aws secretsmanager create-secret --name bgl-signing-key \
    --kms-key-id alias/bnprs-bgl-signing-prod --secret-binary fileb://<decrypted-bgl-kid3.key> \
    --profile bnprs --region ap-south-2
shred -u <decrypted-bgl-kid3.key>
```
Record the resulting ARNs in `key-registry.yaml`. Private value never logged.

## Security (matches the na-003/011 contract)
- **AuthN/AuthZ:** mTLS fleet cert (already enforced at the API GW) — the single forge gate. Optionally
  scope an `Authorization`/claim to the enrollment role + keep the WAF rate limit.
- **Perpetual licenses (exp=0, owner-approved):** revocation = signed offline blocklist by `lid`;
  therefore the issuance log MUST capture every `lid`. hwid-binding limits a leaked token to one machine.
- Private key envelope-encrypted at rest; decrypted only in Lambda memory; never logged/returned.

## Definition of done
- [ ] Owner approves AWS provisioning.
- [ ] CMK + Secrets Manager `bgl-signing-key` created; kid=3 migrated; local plaintext wiped.
- [ ] `bgl-issue` Lambda deployed; `POST /bgl/v1/issue` route live behind mTLS + WAF.
- [ ] Issuance log writing per-token lid records.
- [ ] E2E: real workstation `.req` → token → `bgl-inspect` VALID → activates BprCardQi.

## Done already (this session)
- Decision A taken; kid=3 Ed25519 keypair generated; private key secured (interim local custody);
  public key handed to na-003/011 to embed (retire kid=2). Interim issuance available offline via bgl-issue.
