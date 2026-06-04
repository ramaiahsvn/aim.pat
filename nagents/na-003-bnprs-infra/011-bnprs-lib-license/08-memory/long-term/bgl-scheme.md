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

## Global library-license gate + first lib (BprCardQi) — DONE 2026-06-02

- **Global gate added to the BGL core** (`bgl_gate.c`, API in `bgl.h`): `bgl_activate(token,
  product_id, appid)` remembers a valid token as the library's global license;
  `bgl_is_licensed()` is the cheap guard entry points consult and **re-verifies live** (so
  expiry/clock-rollback revoke access without re-activation). `bgl_deactivate()` clears it.
  Facade: `BprBgl::activate/isLicensed/deactivate`. Tests: **23/23** on macOS arm64.
- **Applied to BprCardQi** (product_id 3): linked BGL into all 3 BprCardQi targets; added C ABI
  exports `bpr_cardqi_activate / bpr_cardqi_is_licensed / bpr_cardqi_hwid`; gated at the
  **single chokepoint `BprPcSc_Context_Init`** — no global license → returns NULL + ec=-900,
  so the library is inert. **`patIsValidLicense` left completely untouched** (per user).
- **Gated on all 3 platform paths** (chokepoint = the context-init entry; legacy `mpos`
  checks untouched everywhere):
  - **macOS** (SO_Linux, PCSC.framework): `libBprCardQi.2.56.4.dylib` — **runtime-verified**:
    Context_Init → NULL/-900 before activate; valid context after activating a kid=2 token
    bound to this machine (product 3). ✅
  - **Windows 32/64** (MinGW cross-build): `libBprCardQi.dll` (PE32+) — gate + exports
    `bpr_cardqi_activate/_is_licensed/_hwid` present in the export table (build-verified).
  - **Android arm64** (NDK r27.2 cross-build): `libBprCardQi.so` — `Java_com_bpr_pcsc_contextInit`
    gated; JNI exports `Java_com_bpr_pcsc_bglActivate/bglIsLicensed/bglHwid` (build-verified).
  - All cross-builds done on pat-m4p; macOS is the only runtime-verified one (can't run PE/ELF here).
- Model confirmed: "if the lib holds the global license, then its functions work."
- Registry reconciled: `mpos` (mPOS solution code BprCardQi gates on) recorded as
  legacy-in-use in [[product-codes]]; BGL global gate uses the lib product_id (3).

## Issuance-model change — DECIDED 2026-06-04 (reverses two earlier pillars)

For the **fleet auto-licensing** of existing BprCardQi workstations, the owner chose:
- **Issuance via API, backed by `na-003/007 bnprs-grc-kms`** — the BGL Ed25519 signing key
  moves into grc-kms (KMS/HSM custody), exposed as a signing endpoint. The workstation enrollment
  exe sends a `.req` (hwid + claims) and receives the signed `.lic` token as the API response.
  **This reverses the original "no grc-kms/HSM dependency, key self-managed by this agent" pillar.**
  Runtime **verification stays fully offline** (token verifies against the embedded public key with
  no network) — only *issuance* becomes online, which is compatible with the offline-only verifier.
- **Perpetual licenses (exp=0) — explicitly approved** by owner for this fleet. Verifier already
  supports it (`if (c.exp && now > c.exp)` skips when exp==0). Tradeoff acknowledged: no
  time-based revocation → the offline signed **blocklist (by `lid`)** becomes the primary
  revocation path and is now higher priority.
- **New forge surface:** the grc-kms signing API must be authN/authZ-gated (only authorized
  enrollment can request a signature) — owned by grc-kms. hwid-binding limits a leaked token to one
  machine; perpetual means it never self-expires, so blocklist + API access control carry the risk.

**Component ownership:** grc-kms (na-003/007) = key custody + signing API; this agent (na-003/011)
= .req/.lic format, claim contract, file-based load/activate in the lib facade, enrollment-exe
source; cpp-card-qi (na-005/002) = build the DLL + the Windows enrollment exe. See [[build-ownership]].

**Issuance endpoint (confirmed by owner 2026-06-04):** `https://kms.bnprs.ai/bgl/v1/issue` — the
`bgl-enroll.exe` default (overridable via `--api`/`BGL_ISSUE_URL`); grc-kms provisions it.

**Source DONE 2026-06-04 (uncommitted in bpr.cpp; build via cpp-card-qi):**
- Spec/contract: `07-axon-terminals/deliverables/design/fleet-enrollment-and-issuance-api.md`.
- Facade `bpr_bgl.{h,cpp}`: `activateFromFile` / `activateFromStore(<storeDir>/<hwid>.lic)` +
  codes kFileNotFound(-101)/kFileEmpty(-102)/kHwidUnavailable(-103). Syntax-checked.
- C ABI exports in `cli/BprCardQi/BprCardQi_dll_exports.cpp`: `bpr_cardqi_activate_from_store`,
  `bpr_cardqi_license_path`; default store `C:\ProgramData\BprCardQi`.
- **Lazy auto-load APPLIED at the DLL chokepoint** `BprPcSc_Context_Init` (verification-preserving;
  Android JNI left unchanged). So existing host apps pick up a dropped `.lic` with no code change.
- Enrollment exe `cli/BprCardQi/enroll/bgl_enroll.c` — Windows/WinHTTP, runtime-loads BprCardQi.dll,
  idempotent, no key; compile-verified PE32+ (build with `-lwinhttp`, NOT `-municode`). Standalone
  `cli/BprCardQi/enroll/CMakeLists.txt` added (decoupled from lib graph; honors LIB_OUTPUT_DIR;
  verified via toolchain_windows_64). Drop-in Makefile target drafted in the cpp-card-qi handoff.
- **Still pending:** grc-kms builds `POST /bgl/v1/issue` (+ auth + lid log); cpp-card-qi builds the
  DLL & exe; no real-device Windows hwid test yet.
- **Handoff SENT to grc-kms 2026-06-04** → its `01-dendrite/inputs/handoff-na003-011-bgl-issuance-api.md`
  (copy logged in our `07-axon-terminals/notifications/2026-06-04-handoff-grc-kms-issuance-api.md`).
  **Key gotcha raised:** AWS KMS cannot Ed25519-sign — recommended grc-kms generate a new kid
  Ed25519 key, envelope-encrypt under a KMS data key, hand us the pubkey to embed (retire kid=2),
  then cpp-card-qi rebuilds the DLL with the new kid. Awaiting grc-kms custody decision (A vs B).
- **Build handoff SENT to cpp-card-qi (na-005/002) 2026-06-04** → its
  `01-dendrite/inputs/handoff-na003-011-bgl-build.md` (copy in our notifications). Asks: build
  BprCardQi DLL (new exports + lazy-load, bpr.cpp @ `f75cd85`; suggest bump 2.56.4→2.56.5) + the new
  `bgl-enroll.exe` (needs a build target; `-lwinhttp`, no `-municode`). Interim kid=2 test builds OK;
  final fleet DLL must embed grc-kms's chosen kid (011 will ping to rebuild). Real-Windows hwid test
  still the standing gap.
- **grc-kms ACTIONED 2026-06-04 (decision A):** generated **kid=3** Ed25519 signing key under its
  custody (supersedes kid=2; KMS can't Ed25519-sign so it's software-key + KMS-envelope). Pubkey
  handed back → `011/01-dendrite/inputs/2026-06-04-keyhandback-grc-kms-kid3.md`
  (hex `2aa9e4b2…2c373ee5`). **Our next action:** embed it in `bgl_pubkeys.h`, retire kid=2, then
  ping cpp-card-qi to build. Production issuance API at kms.bnprs.ai is a runbook on the existing
  k3-verifychallenge stack, PENDING owner approval to provision AWS; interim issuance via offline
  `bgl-issue` with the kid=3 key.
- **kid=3 EMBEDDED 2026-06-04 (bpr.cpp @ `8d3dcc7`):** `bgl_pubkeys.h` now `BGL_KID 3`
  (pubkey `2aa9e4b2…2c373ee5`), kid=2 retired (old tokens → UNKNOWN_KID). Verified: rebuilt tools,
  kid=3 issue→inspect signature VALID, `bgl-test` 23/23. Notified cpp-card-qi the kid is final →
  fleet DLL build cleared. **Remaining:** cpp-card-qi builds DLL+exe; grc-kms API deploy pending
  owner approval; real-Windows hwid test.
- **Real-Windows test (2026-06-04):** BprCardQi 2.56.5 windows-64 + bgl-enroll.exe run on a live
  station — **DLL loaded, hwid derived OK** (`0018d9e6…adad8`) → the standing Windows-hwid gap is
  CLEARED. Issued that station a kid=3 perpetual `.lic` offline via `bgl-issue` (in
  `bpr.cpp/build/win-test/`).
- **Online auto-licensing wired (owner: "use the API, no key in exe") 2026-06-04:** the station
  fetches its license over the **existing fleet mTLS channel** — DLL `BglFetchLicenseToken` reuses
  the k3-verifychallenge cert path (`BprCardQi.cpp`), new export **`bpr_cardqi_fetch_license`**
  POSTs the .req to `kms.bnprs.ai/bgl/v1/issue`, writes+activates `<hwid>.lic`. **`bgl-enroll.exe`
  is now keyless AND httpless** (no WinHTTP; just calls the DLL). Signing stays server-side in
  grc-kms; the only client credential is the existing fleet mTLS cert (auth, not signing).
  grc-kms signing **Lambda code written** (`007/.../deliverables/bgl-issue-lambda/`, Rust + deploy.sh)
  — **AWS deploy HELD pending owner approval**. Until deployed, the exe's online path fails over to
  writing `<hwid>.req` (offline issuance still works).

**Next (Phase 3+):** migrate other libs' call sites to `bgl_verify` (dual-accept window);
Linux/Windows hwid real-device testing; wrap via na-003/010 for Java/.NET/Go; offline signed
blocklist + anti-rollback high-water mark; harden signing-key storage. **Why:** user granted freedom to replace the
legacy scheme; this is the chosen direction. **How to apply:** build Phase 1 (desktop
bgl_verify + bgl_hwid + test keypair) first; never put the signing key in a shipped artifact;
preserve product_id/code4 immutability from [[product-codes]].
