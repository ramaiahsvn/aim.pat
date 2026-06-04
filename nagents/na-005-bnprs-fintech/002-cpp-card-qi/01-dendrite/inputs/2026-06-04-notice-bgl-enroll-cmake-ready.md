# NOTICE → na-005/002 cpp-card-qi

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Type:** update to an open handoff

## bgl-enroll CMake target is READY

The standalone build for the enrollment tool is committed and pushed:

> **`bpr.cpp/cli/BprCardQi/enroll/CMakeLists.txt`** (origin/main @ `6c7e2eb`)

- Decoupled from the lib graph (links only WinHTTP; the exe runtime-loads `BprCardQi.dll`), mirrors
  the `gnd-raspberry` standalone pattern, honors `LIB_OUTPUT_DIR`, and forbids `-municode`.
- **Verified end-to-end** through `toolchains/toolchain_windows_64.cmake` → PE32+ console exe.
- Configure/build:
  ```
  cmake -S cli/BprCardQi/enroll -B build/bgl-enroll/windows-64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$PWD/toolchains/toolchain_windows_64.cmake" \
        -DLIB_OUTPUT_DIR="$PWD/build/bnprs-libs/bgl-enroll/windows-64"
  cmake --build build/bgl-enroll/windows-64 --config Release
  ```
- A **drop-in Makefile target** (`bgl-enroll-windows-64`, using your existing vars) is in your open
  handoff `01-dendrite/inputs/handoff-na003-011-bgl-build.md` §2 — the Makefile edit is yours to make.

No change to the rest of the build ask (DLL with new exports + lazy-load, suggested 2.56.4→2.56.5,
final fleet DLL must embed grc-kms's chosen kid). Reply via
`na-003/011 .../07-axon-terminals/notifications/` or BNA.
