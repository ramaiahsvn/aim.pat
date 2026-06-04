# OUTGOING HANDOFF → na-003/007 bnprs-grc-kms

**Date:** 2026-06-04 · **Status:** SENT, awaiting grc-kms

**What:** Requested grc-kms build the BGL token signing API `POST /bgl/v1/issue` (Ed25519 key in
grc-kms custody; issuance log with `lid`). Backend for BprCardQi fleet auto-licensing.

**Delivered to:**
`na-003-bnprs-infra/007-bnprs-grc-kms/01-dendrite/inputs/handoff-na003-011-bgl-issuance-api.md`

**Key open decision flagged to them:** AWS KMS can't Ed25519-sign → recommended (A) grc-kms generate
a new kid Ed25519 keypair, envelope-encrypt the secret under a KMS data key, hand us the public key
to embed + retire kid=2. Alternative (B) import existing kid=2 secret.

**Blocks on us once they reply (option A):** embed their public key in `bgl_pubkeys.h`, retire kid=2,
then na-005/002 cpp-card-qi rebuilds BprCardQi DLL with the new kid + the new exports.
