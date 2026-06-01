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
- **Offline-ONLY** signed token: `BGL1.<b64url(cbor payload)>.<b64url(ed25519 sig)>`. No
  network at any point — no online activation, phone-home, or CRL fetch. Revocation is
  offline: short expiry + re-issue, or a signed blocklist of `lid`s bundled with lib/public-key
  updates.
- **Asymmetric Ed25519**: issuer's **private key signs**, **self-managed by this agent**
  (encrypted at rest on the issuer host, value never committed, referenced by alias/kid —
  **no grc-kms/HSM dependency**); **public key compiled into each lib** verifies. Binary can
  verify, never forge — fixes the legacy symmetric weakness. `kid` claim enables key rotation
  (and is the compromise-recovery path). Optional hardware-token hardening is a future,
  non-blocking add.
- **Binding**: hwid (desktop/server/Pi) or appid (mobile — iOS/Android have no stable hwid).
  `bid = SHA-256(normalized id)`; raw id never stored. `bind` claim records which.
- **Claims**: product_id(s) from [[product-codes]], platform set, feature bitmask, iat/nbf/exp,
  lid (UUID), kid. (No seat/activation claim — offline-only.)
- **Verifier** = tiny pure-C `bgl_verify()` in BprLicBase v3 (bundled Ed25519+SHA-256, no
  OpenSSL); wraps via na-003/010 for Java/.NET/Go. Legacy `patIsValidLicense` kept as a
  migration bridge (dual-accept).

**Cross-agent:** publish BprLicBase v3 ↔ na-003/009 lib-forge; language wrappers ↔ na-003/010
multisdk; call-site migration ↔ na-004/na-005. **Signing-key custody is self-managed by this
agent — no grc-kms/HSM dependency.**

**Open owner decisions:** offline-only (confirmed), expiry-always vs perpetual, exact-hwid vs
M-of-N tolerance.

## Phase 1 — DONE (2026-06-02), builds & 18/18 tests pass

Implemented in **`bpr.cpp/src/AprCommon/BprLicense/bgl/`** (separate repo; not in aim.pat):
- Wire spec FROZEN → `bgl/BGL-TOKEN-SPEC.md`. v1 uses a **fixed big-endian binary claim
  block** (86B + product list), not CBOR — keeps the verifier tiny. `BGL1.<b64url block>.<b64url sig>`.
- Crypto: vendored **TweetNaCl** (`bgl/vendor/`) — Ed25519 + SHA-512; bid = SHA-512(id)[:32].
  One crypto file, no OpenSSL. `randombytes` = /dev/urandom (keygen only).
- Verifier core (`bgl_token.c`, `bgl_verify.c`, `bgl_hwid.c`, `bgl_keys.c`) + public API `bgl.h`
  (`bgl_verify`, `bgl_hwid`, `bgl_appid`, `bgl_platform_bit`, reason codes).
- hwid: **macOS = IOPlatformUUID+hw.model (IOKit)** [tested], Linux = machine-id+DMI,
  Windows = MachineGuid+volserial (#ifdef, untested), Raspberry detect. appid = lowercased id.
- Tools: `bgl-keygen`, `bgl-issue`, `bgl-inspect`. Test keypair generated; **public key embedded
  in `bgl/bgl_pubkeys.h` (kid=1, committed); private `bgl.key` is git-ignored (never commit)**.
- CMake builds lib+tools+test; `bgl-test` = KAT (b64url, claims round-trip) + e2e issue→verify
  + negatives (tamper, wrong product/platform, expired, not-yet, wrong/missing binding, unknown kid).
  **18/18 pass on macOS arm64.** Verified `bgl-issue --hwid-here` → `bgl-inspect` = signature VALID.

## Phase 2 — DONE (2026-06-02): BprLicBase v3 integration

BGL is now part of **BprLicBase, bumped 2.27.4 → 2.27.5** (in bpr_versions.h, .cmake, Makefile).
- C++ facade `src/AprCommon/BprLicense/bpr_bgl.{h,cpp}` → `BprBgl::verify/verifyReason/hwid/appidHash/reasonStr` over the C bgl API.
- New C ABI exports in `cli/BprLicense/BprLicense_dll_exports.cpp`: `bpr_bgl_verify`,
  `bpr_bgl_hwid`, `bpr_bgl_reason_str` — **alongside** the untouched legacy
  `bpr_is_valid_license`/`patIsValidLicense` = **dual-accept**.
- CMake: bgl sources + bpr_bgl.cpp wired into the **BprLicBase target only** (zero blast
  radius on other libs); include dir + IOKit/CoreFoundation linked on Apple.
- **Verified** on macOS arm64: built `libBprLicBase.2.27.5.dylib`; a machine-bound token from
  `bgl-issue` verifies OK through `bpr_bgl_verify` (prod 2=OK, prod 9=WRONG_PRODUCT), `bpr_bgl_hwid`
  returns this machine's id, and legacy `bpr_is_valid_license` still links/works in the same lib.

## Signing-key custody (rotated 2026-06-02)

- **Active key id: kid=2.** kid=1 was the Phase-1 test key — **retired** (removed from
  `bgl_pubkeys.h`; old kid=1 tokens no longer verify; none were issued for real).
- **Working private key** (issuer): `bpr.cpp/src/AprCommon/BprLicense/bgl/bgl.key` — 64-byte
  Ed25519 secret, perms `600`, **git-ignored** (never committed; `*.key` in bgl/.gitignore).
  Used by `bgl-issue`.
- **Public key (kid=2)** is committed in `bgl/bgl_pubkeys.h` and shipped in BprLicBase — safe.
- **Encrypted backup**: `~/BPR/.keys-backup/bgl/bgl-kid2.key.enc` (AES-256-CBC, PBKDF2 200k,
  perms 600, **outside both git repos**). Passphrase stored in macOS **Keychain** service
  **`bgl-kid2-signing-key`** (retrieve: `security find-generic-password -s bgl-kid2-signing-key -w`).
  Round-trip verified. Per the key-material rule only these **references** are recorded here —
  never the key or passphrase value.
- **Offsite backup (DONE 2026-06-02)** — the two halves are stored separately, off pat-m4p:
  - Encrypted blob `bgl-kid2.key.enc` → **Zoho WorkDrive**:
    `https://workdrive.zoho.com/file/50ypbc9b2fa246c5a4927b5d178e0a677b874`
  - Passphrase → **Zoho Vault** (entry for `bgl-kid2-signing-key`).
  - Local copies of the blob also at `~/BPR/.keys-backup/bgl/` and `~/Desktop/bgl-kid2.key.enc`
    (working copies); passphrase also in macOS Keychain `bgl-kid2-signing-key`.
  - To recover: download the blob, get the passphrase from Zoho Vault, then
    `openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in bgl-kid2.key.enc -out bgl.key`.
  - Blob and passphrase are kept in **separate** stores (WorkDrive vs Vault) — never together.
- **Rotation procedure** (if compromised/lost): `bgl-keygen <newkid> bgl.key bgl_pubkeys.h` →
  rebuild → re-embed → re-issue active licenses → ship libs with the new public key.

**Next (Phase 3+):** migrate other libs' call sites to `bgl_verify` (dual-accept window);
Linux/Windows hwid real-device testing; wrap via na-003/010 for Java/.NET/Go; offline signed
blocklist + anti-rollback high-water mark; harden signing-key storage. **Why:** user granted freedom to replace the
legacy scheme; this is the chosen direction. **How to apply:** build Phase 1 (desktop
bgl_verify + bgl_hwid + test keypair) first; never put the signing key in a shipped artifact;
preserve product_id/code4 immutability from [[product-codes]].
