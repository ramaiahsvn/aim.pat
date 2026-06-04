# HANDOFF → na-005/002 cpp-card-qi

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Priority:** normal · **Status:** OPEN

## Ask (one line)
Build two artifacts for BprCardQi fleet auto-licensing: **(1)** the BprCardQi DLL with the new
BGL file-load exports + chokepoint lazy-load, and **(2)** the new Windows enrollment exe
`bgl-enroll.exe`. All source is committed in **bpr.cpp @ `f75cd85`** (pushed to origin/main).

## What changed in source (already committed — you own the build)
Commit `f75cd85` — "feat(BprCardQi/BGL): file-based license load + lazy gate auto-load + enrollment exe":

1. **`src/AprCommon/BprLicense/bpr_bgl.{h,cpp}`** — facade gains `activateFromFile()` /
   `activateFromStore("<storeDir>/<hwid>.lic")` + error codes -101/-102/-103. (Already in `BGL_SOURCES`
   → compiles into the BprLicBase + BprCardQi targets, no CMake change needed.)
2. **`cli/BprCardQi/BprCardQi_dll_exports.cpp`** — two new C ABI exports:
   - `int bpr_cardqi_activate_from_store(const char* storeDir)` — NULL/"" → default
     `C:\ProgramData\BprCardQi`; reads `<hwid>.lic`, activates; 0==OK.
   - `int bpr_cardqi_license_path(char* out, int cap)` — default `<store>\<hwid>.lic`.
   - **`BprPcSc_Context_Init` now lazy-loads** `<hwid>.lic` before refusing (so existing host apps
     pick up a dropped license with no code change; verification unchanged). Android JNI untouched.
3. **`cli/BprCardQi/enroll/bgl_enroll.c`** — NEW Windows console tool (no build wiring yet — see §2).

## 1) BprCardQi DLL
- Build entry already exists: `make BprCardQi-windows-64` (mingw-w64). I compile-verified the facade
  (syntax) and the exe; I did **not** run the full DLL build — that's yours (you hold the build history).
- Recommend the platforms you ship for this fleet: **windows-64** (primary), windows-32 and
  android-arm64 for parity (Android won't use file-load, but the exports are harmless there).
- **Version bump:** these are additive ABI exports → suggest **2.56.4 → 2.56.5** in
  `bpr_versions.h` / `.cmake` / Makefile. Your call / your bookkeeping.
- **kid ordering (important):** the gate/exports/lazy-load are **kid-independent**, so you can build
  and smoke-test now with the current **kid=2** pubkey. BUT the *final fleet DLL* must embed whatever
  kid grc-kms settles on — na-003/007 is deciding (likely a new kid under KMS custody; see their
  handoff). When they hand 011 the new public key, 011 updates `bgl_pubkeys.h` and pings you to
  rebuild. **Don't ship the fleet DLL before that kid is final**; interim test builds are fine.

## 2) bgl-enroll.exe (new — needs a build target)
- Source: `cli/BprCardQi/enroll/bgl_enroll.c`. Pure Win32 + WinHTTP; runtime-loads the deployed
  `BprCardQi.dll` (does NOT link the lib at build time), so it needs no bpr.cpp object deps.
- **Verified build command** (mingw-w64 x86_64):
  ```
  x86_64-w64-mingw32-gcc -O2 -o bgl-enroll.exe cli/BprCardQi/enroll/bgl_enroll.c -lwinhttp
  ```
  → produces a PE32+ console exe. **Do NOT pass `-municode`** (it forces a wide `wmain` entry and
  fails to link — the tool uses a normal ANSI `main`).
- Please add the canonical target (Makefile/CMake) in whatever shape fits your build system — it's a
  standalone exe, not one of the `OUTFILENAME` libs, so it likely wants its own small rule rather
  than the lib `BUILD_RULE` macro.

## Definition of done
- [ ] `libBprCardQi.dll` (windows-64 at least) built; export table shows
      `bpr_cardqi_activate / _is_licensed / _hwid / _activate_from_store / _license_path`.
- [ ] Lazy-load behaves: with a valid `C:\ProgramData\BprCardQi\<hwid>.lic` present,
      `BprPcSc_Context_Init` succeeds with **no** explicit `bpr_cardqi_activate` call; with none/invalid
      → returns NULL + ec=-900.
- [ ] `bgl-enroll.exe` builds (PE32+) and `bgl-enroll --offline` writes `<hwid>.req`.
- [ ] (the standing gap) at least one **real Windows device** test of hwid derivation
      (`MachineGuid` + C: volume serial) — never runtime-verified on real Windows yet.
- [ ] Final fleet DLL embeds grc-kms's chosen kid (rebuild after 011 updates `bgl_pubkeys.h`).

## Coordination
- **na-003/011** (this agent): owns the licensing source + the kid/pubkey embed; will ping you to
  rebuild once grc-kms's kid is final.
- **na-003/007 grc-kms**: building the issuance API + key custody (kid decision pending).
- Questions/replies: note in `na-003/011 .../07-axon-terminals/notifications/` or via BNA.
