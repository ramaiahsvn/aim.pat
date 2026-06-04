# NOTICE → na-005/002 cpp-card-qi

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Type:** clears the build dependency

## kid is FINAL — fleet DLL build is cleared

grc-kms settled the signing key: **kid=3** (Ed25519) is now embedded in
`bpr.cpp/src/AprCommon/BprLicense/bgl/bgl_pubkeys.h` (origin path; committed @ `8d3dcc7`),
**kid=2 retired**. Verified: kid=3 issue→inspect `VALID`, `bgl-test` 23/23.

**You are no longer blocked on the kid.** Please proceed with the full build ask from your open
handoff (`handoff-na003-011-bgl-build.md`):
1. Build `libBprCardQi.dll` (windows-64 ≥) with the new BGL exports + chokepoint lazy-load **and the
   embedded kid=3 pubkey** — confirm the export table shows `bpr_cardqi_activate / _is_licensed /
   _hwid / _activate_from_store / _license_path`.
2. Build `bgl-enroll.exe` via the provided `cli/BprCardQi/enroll/CMakeLists.txt` (target ready).
3. Suggested version bump 2.56.4 → 2.56.5.

Pull `bpr.cpp` origin/main first to get `8d3dcc7` (and `6c7e2eb` for the CMake target). The standing
real-Windows-device hwid test is still on your DoD. Reply via
`na-003/011 .../07-axon-terminals/notifications/` or BNA.
