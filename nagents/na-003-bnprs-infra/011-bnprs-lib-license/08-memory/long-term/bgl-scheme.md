---
name: bgl-scheme
description: BGL — the new cross-platform global licensing scheme design for bpr.cpp libs (na-003/011)
metadata:
  node_type: memory
  type: project
---

**BGL (BNPRS Global License) v1** — the new global licensing scheme replacing the legacy
symmetric `patIsValidLicense`. Full design:
`07-axon-terminals/deliverables/design/global-licensing-scheme.md`.

**Core architecture (decided as product-architect plan, pending owner sign-off):**
- **Offline-verifiable** signed token: `BGL1.<b64url(cbor payload)>.<b64url(ed25519 sig)>`.
- **Asymmetric Ed25519**: issuer's **private key signs** (ideally in the HSM at kms.bnprs.ai,
  via na-003/007); **public key compiled into each lib** verifies. Binary can verify, never
  forge — fixes the legacy symmetric weakness. `kid` claim enables key rotation.
- **Binding**: hwid (desktop/server/Pi) or appid (mobile — iOS/Android have no stable hwid).
  `bid = SHA-256(normalized id)`; raw id never stored. `bind` claim records which.
- **Claims**: product_id(s) from [[product-codes]], platform set, feature bitmask, iat/nbf/exp,
  lid (UUID), kid, optional seat count.
- **Verifier** = tiny pure-C `bgl_verify()` in BprLicBase v3 (bundled Ed25519+SHA-256, no
  OpenSSL); wraps via na-003/010 for Java/.NET/Go. Legacy `patIsValidLicense` kept as a
  migration bridge (dual-accept).

**Cross-agent:** signing key ↔ na-003/007 grc-kms (HSM); publish BprLicBase v3 ↔ na-003/009
lib-forge; language wrappers ↔ na-003/010 multisdk; call-site migration ↔ na-004/na-005.

**Open owner decisions:** offline-first (assumed), expiry-always vs perpetual, revocation in
v1 vs Phase-3, exact-hwid vs M-of-N tolerance. **Why:** user granted freedom to replace the
legacy scheme; this is the chosen direction. **How to apply:** build Phase 1 (desktop
bgl_verify + bgl_hwid + test keypair) first; never put the signing key in a shipped artifact;
preserve product_id/code4 immutability from [[product-codes]].
