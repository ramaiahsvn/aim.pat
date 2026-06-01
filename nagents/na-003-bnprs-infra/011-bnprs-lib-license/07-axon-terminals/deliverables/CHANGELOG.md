# BGL — project changelog (bnprs-lib-license, na-003/011)

> Consolidated timeline of the BGL (BNPRS Global License) effort. Commit refs span two
> repos: **A** = aim.pat (agent records), **C** = bpr.cpp (implementation). Newest last.
> Design: `deliverables/design/global-licensing-scheme.md` · Journal: `08-memory/long-term/bgl-scheme.md`.

## 2026-06-01 — agent, design, decisions

- **Create agent** `bnprs-lib-license` (na-003/011) — hwid/appid licensing for all bpr.cpp libs. `A 9a91b45`
- **Product-code registry** defined (`product-codes.yaml`): per-lib product_id + 4-char code4; `qemv` reserved. `A 690521c`
- **BGL designed** — offline-verifiable, Ed25519-signed token bound to hwid (desktop/Pi) or appid (mobile); product/platform/feature/expiry claims; pure-C verifier. `A d7ea79c`
- **Decision: no HSM** — signing key self-managed (encrypted at rest), not grc-kms. `A 8062946`
- **Decision: offline-only** — removed online activation / CRL / seat counting; revocation via short expiry + re-issue or bundled blocklist. `A 54f474f`, `A 0a9a9f2`

## 2026-06-02 — Phase 1: offline verifier (bpr.cpp/src/AprCommon/BprLicense/bgl/)

- Frozen binary token spec; vendored TweetNaCl (Ed25519+SHA-512); `bgl_verify`/`bgl_hwid`/`bgl_appid`; macOS IOKit hwid (+Linux/Windows #ifdef); keygen/issue/inspect tools; embedded test pubkey (private key git-ignored). **18/18 tests pass** on macOS arm64. `C bcebabe`, `A 0f81fd2`

## 2026-06-02 — Phase 2: BprLicBase v3 integration (dual-accept)

- BGL exposed from **BprLicBase 2.27.4 → 2.27.5**: `BprBgl` C++ facade + `bpr_bgl_verify/_hwid/_reason_str` C ABI, **alongside untouched legacy `patIsValidLicense`**. Scoped to the BprLicBase target. Verified on macOS (`libBprLicBase.2.27.5.dylib`). `C 89deaab`, `A dc1be3d`

## 2026-06-02 — Key rotation + backup

- **Rotated kid=1 → kid=2** (kid=1 was the Phase-1 test key, retired); rebuilt + re-tested. `C 8f09986`, `A f4a7e18`
- **Encrypted backup**: AES-256/PBKDF2 blob; passphrase in macOS Keychain; then offsite — blob on **Zoho WorkDrive**, passphrase in **Zoho Vault** (stored separately). `A 051423d`

## 2026-06-02 — Phase 3: global library-license gate + BprCardQi (all platforms)

- **Global gate** added to BGL core (`bgl_activate`/`bgl_is_licensed`/`bgl_deactivate`; re-verifies live). 23/23 tests. Applied to **BprCardQi** (product_id 3) at the context-init chokepoint — no global license ⇒ library inert; legacy `patIsValidLicense("mpos")` untouched. `C 7dff461`, `A d41c68d`
- Registry reconciled: `mpos` (mPOS/BPR1003 code BprCardQi gates on) recorded as legacy-in-use. `A d41c68d`
- **Android JNI** path gated too (`Java_com_bpr_pcsc_contextInit` + `bglActivate/bglIsLicensed/bglHwid`). `C ff674a7`, `A ee3ccf7`

### Platform coverage (BprCardQi gate)

| Platform | Build | Gate verification |
|----------|:-----:|-------------------|
| macOS (SO_Linux, PCSC.framework) | ✅ | **runtime-verified** (NULL/-900 → valid after activate) |
| Windows 32/64 (MinGW cross) | ✅ | exports present (build-verified) |
| Android arm64 (NDK r27.2 cross) | ✅ | JNI exports present (build-verified) |

> All cross-built on pat-m4p; macOS is the only runtime-verified target (can't run PE/ELF here).

## Open / next

- Runtime-verify Windows + Android on real hosts/devices (with PC/SC card hardware).
- Apply the global gate to other libs (BprFace, BprICBA, …).
- Offsite copy hygiene: WorkDrive blob + Vault passphrase kept in separate stores (done).
- Future, non-blocking: hardware-token signing; offline signed blocklist + anti-rollback (Phase 3+ of the design).
