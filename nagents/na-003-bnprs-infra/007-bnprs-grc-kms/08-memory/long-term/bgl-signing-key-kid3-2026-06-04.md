---
name: bgl-signing-key-kid3
description: grc-kms now custodies the BGL Ed25519 license signing key (kid=3); issuance API runbook pending AWS provisioning
metadata:
  node_type: memory
  type: project
---

**grc-kms actioned the na-003/011 BGL issuance handoff on 2026-06-04 — decision A.**

- **Why a software Ed25519 key, not a KMS key:** BGL tokens are Ed25519 and the public key is compiled
  into shipped libs; **AWS KMS cannot Ed25519-sign** (only RSA/ECC-NIST/HMAC). So the signing key is
  software-generated and held under grc-kms custody, with AWS KMS used to *envelope-encrypt* it at rest.
- **kid=3 generated** (`bgl-keygen`), superseding the self-managed kid=2 test key (no real licenses
  issued on kid=2). Public key handed to na-003/011 to embed in `bgl_pubkeys.h` + retire kid=2.
  Pubkey hex `2aa9e4b21cf7dc0a241df00f88af439fa16f4b10c14ff330ecc691142c373ee5`.
- **Interim custody:** `~/BPR/.keys-backup/bgl/bgl-kid3.key.enc` (AES-256/PBKDF2, outside git),
  passphrase in Keychain `bgl-kid3-signing-key`. References only — see [[key-registry]] signing_keys.
- **Target:** Secrets Manager `bgl-signing-key` + CMK `alias/bnprs-bgl-signing-prod`, signed by a new
  Rust Lambda `bgl-issue` on the EXISTING `kms.bnprs.ai` API GW `8nlf3cfyd9` (reuses the
  k3-verifychallenge mTLS fleet cert + WAF). Runbook: `07-axon-terminals/deliverables/bgl-issuance-api-runbook.md`.
- **PENDING owner approval:** the production AWS provisioning (CMK, Secrets Manager, Lambda, route) —
  gated per guardrails; not executed. Until live, grc-kms can issue tokens offline via `bgl-issue`.
- **Perpetual licenses (exp=0)** ⇒ revocation = signed offline blocklist by `lid`; the issuance log
  must capture every lid. **How to apply:** when approved, follow the runbook's atomic
  generate→store→wipe key migration; never log the secret value.
