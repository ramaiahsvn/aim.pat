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
- **A standalone `CMakeLists.txt` is now provided** at `cli/BprCardQi/enroll/CMakeLists.txt`
  (bpr.cpp @ `5990c8a`+). It's decoupled from the lib graph (links only WinHTTP), mirrors the
  `gnd-raspberry` standalone pattern, honors `LIB_OUTPUT_DIR`, and forbids `-municode`.
  **Verified** end-to-end through `toolchains/toolchain_windows_64.cmake` → PE32+ exe.
  ```
  cmake -S cli/BprCardQi/enroll -B build/bgl-enroll/windows-64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$PWD/toolchains/toolchain_windows_64.cmake" \
        -DLIB_OUTPUT_DIR="$PWD/build/bnprs-libs/bgl-enroll/windows-64"
  cmake --build build/bgl-enroll/windows-64 --config Release
  ```
- **Drop-in Makefile target** (uses your existing vars; mirrors `gnd-raspberry`):
  ```makefile
  # bgl-enroll — standalone Windows enrollment tool (na-003/011); links only WinHTTP.
  BGL_ENROLL_SRC := cli/BprCardQi/enroll

  .PHONY: bgl-enroll-windows-64
  bgl-enroll-windows-64:
  	@echo ""
  	@echo "=== Building bgl-enroll for windows-64 ==="
  	@mkdir -p $(BUILD_DIR)/bgl-enroll/windows-64
  	@mkdir -p $(OUT_DIR)/bgl-enroll/windows-64
  	cmake -S $(BGL_ENROLL_SRC) -B $(BUILD_DIR)/bgl-enroll/windows-64 \
  	    -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
  	    -DCMAKE_TOOLCHAIN_FILE="$(CURDIR)/$(TOOLCHAIN_windows-64)" \
  	    -DLIB_OUTPUT_DIR="$(CURDIR)/$(OUT_DIR)/bgl-enroll/windows-64"
  	cmake --build $(BUILD_DIR)/bgl-enroll/windows-64 --config $(BUILD_TYPE)
  ```
  Adopt/relocate as fits your build system — the Makefile is your canonical file, so I left the
  actual edit to you; the `CMakeLists.txt` is committed and ready.

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
