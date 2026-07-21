# TP9000 Feeder Bench Runbook — task-002.5

**Agent:** na-005/010 bruid-iperso · **Date:** 2026-07-21 · **Task:** task-002.5 (bench-verify the
Pointman TP9000 feeder transport on the Windows perso host).

> This bench CANNOT run on pat-m4p (macOS): `TP9000.dll` is a Win32 DLL and needs the physical feeder.
> It runs on the **Windows perso host** with a TP9000 attached. Everything else is prepared and de-risked.

## De-risk already done (pat-m4p, 2026-07-21)
The never-before-compiled Win32 transport code was **cross-compiled against real Windows headers**
(mingw-w64) to catch build errors before the bench:

| Source | i686 (32-bit) | x86_64 (64-bit) |
|--------|:---:|:---:|
| `BprPcSc/tp9k/tp9k_v2.cpp` (Tp9000CardV2) | ✅ clean | ✅ clean |
| `persoengine/src/card_tp9000.cpp` (Tp9000Channel) | ✅ clean | ✅ clean |
| `persoengine/apps/tp9000-probe/main.cpp` | ✅ clean | ✅ clean |

Only warning: `-Wcast-function-type` on the `GetProcAddress` cast — benign, same idiom the legacy
`tp9k.cpp` uses. The legacy wrapper is untouched (it needs MFC/`afx.h`, so it does NOT cross-compile —
expected; it builds under MSVC on the host as before).

**Still unproven until the bench:** (1) the full **persoengine core** built on Windows (pugixml + OpenSSL +
glog — the MC/Visa live runs were all on macOS, so a Windows build of the core is new); (2) live feeder
behaviour (feed / ATR / IC_Input RX sizing / T=0-vs-T=1 / eject).

## Prerequisites on the Windows host
1. **Toolchain:** Visual Studio 2019+ (C++ Desktop) or clang-cl, and CMake ≥ 3.16.
2. **persoengine deps:** pugixml, OpenSSL, glog, GoogleTest — recommend **vcpkg**:
   `vcpkg install pugixml openssl glog gtest` (match the triplet to the build: `x86-windows` or
   `x64-windows`). Pass `-DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake`.
3. **TP9000 vendor runtime:** `TP9000.dll` (+ its own deps) present **next to the built exe**, and the
   **bitness must match the build** (x86 exe ⇒ 32-bit TP9000.dll). The wrapper loads it from the exe
   directory first, then the search path.
4. **Hardware:** TP9000 feeder powered + connected; hopper loaded with blank UAT cards (same Gemalto
   multi-app cards used for the MC/Visa proofs).
5. **Keys:** copy the engine keystore next to where you run the app — `persoengine/keys/uat_keystore.txt`
   must be at `.\keys\uat_keystore.txt` in the working dir (as on macOS). NEVER commit key values.

## Build (from `bpr.cpp/src/BprCardEmv/persoengine`)
**Easiest — the helper script** (`scripts/build-tp9000.ps1`) turns on both transports and builds the probe
+ perso-live-visa:
```powershell
.\scripts\build-tp9000.ps1                    # 32-bit Release (default)
.\scripts\build-tp9000.ps1 -Arch x64          # 64-bit
.\scripts\build-tp9000.ps1 -Arch x64 -Probe   # build, then run the read-only probe
```
It needs `$env:VCPKG_ROOT` set (or pass `-VcpkgRoot <path>`); run `-Clean` to reconfigure from scratch.

**Or the raw CMake** it wraps:
```powershell
# 32-bit example (use -A x64 + the x64 vcpkg triplet for 64-bit)
cmake -S . -B build-win -A Win32 `
  -DPERSOENGINE_BUILD_PCSC=ON `
  -DPERSOENGINE_BUILD_TP9000=ON `
  -DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake `
  -DVCPKG_TARGET_TRIPLET=x86-windows
cmake --build build-win --config Release
```
Targets produced: `persoengine_tp9000`, **`perso-tp9000-probe`**, and `perso-live-visa`
(now linked with `PERSOENGINE_HAVE_TP9000` so it accepts `--transport tp9000`).

## Prebuilt probe exe (no Windows toolchain needed) — delivered 2026-07-21
For a TeamViewer test WITHOUT setting up MSVC/vcpkg/CMake on the host, a standalone
**`perso-tp9000-probe.exe`** was cross-compiled on pat-m4p (mingw-w64, statically linked) and sent to the
user — 32-bit + 64-bit. Only deps are KERNEL32 + the UCRT (OS-provided on Win10/11/Server2016+); `TP9000.dll`
is loaded at RUNTIME (not linked). Match the exe bitness to the DLL (start with win32 — the MCES2 host is x86).
- SHA-256 win32 `3f25ade5327a247d32dc68ec08656bfc49450e27c63b40214dd70b8f05cedb72`
- SHA-256 win64 `ee65eeb65a072450e6445fb5d295e76813c8e43d19785a01aabb2d70277598ea`
Put the exe next to `TP9000.dll` + run it (see the shipped `README-tp9000-probe.txt`). This covers Step 1
below without a host build. The full live perso (Step 2) still needs the host build (OpenSSL/pugixml).

## Step 1 — read-only smoke probe (non-destructive)
```powershell
cd build-win\Release          # or wherever the exe + TP9000.dll + .\keys live
.\perso-tp9000-probe.exe
```
**Expected:** a card feeds from the hopper, EMV cold reset prints an **ATR**, then `SELECT` of the MC
(`A000000004000000`) and Visa (`A000000003000000`) card-manager AIDs returns SW (typically `9000`),
then the card **ejects as good**. No DELETE/INSTALL/STORE DATA is sent.
- Reject-path check (optional): `.\perso-tp9000-probe.exe --reject-test` → card diverts to the reject bin.

**If it fails:** the probe prints the vendor detail (`Get_Status`) via `lastError()`. Common causes:
DLL bitness mismatch, `TP9000.dll` not next to the exe, feeder not homed, or no card in the hopper.

## Step 2 — end-to-end Visa perso over the feeder (DESTRUCTIVE)
Reuses the proven Visa stream (this agent mem-026). **Use a fresh OP_READY UAT card** (a card that was
over-secured cannot be re-personalized without C-MAC).
```powershell
.\perso-live-visa.exe                          # PREFLIGHT over the feeder? -> add --transport tp9000:
.\perso-live-visa.exe --transport tp9000       # preflight (read-only) over the feeder
.\perso-live-visa.exe --commit --transport tp9000   # LIVE: install + write the Visa instance
```
**Expected (matches the macOS/PC-SC proof, mem-026):** `19/19` DGIs → `9000`, applet
SELECTABLE→PERSONALIZED, card SECURED after a passing GPO, self-verify all pass (GPO returns AIP 3800 +
AFL; READ SFI1/2/3 rec1 → 9000; PAN/Name/Track2 read back; VERIFY PIN 1234 → 9000), ending
`=== VISA PERSO COMPLETE ===`. On success the card ejects good; on any failure it is diverted to the
reject bin (RAII disposition in `CardTransport`).

## What to watch / report back
- **RX buffer:** the probe/channel read into fixed buffers (`IC_Input` RX = 512B; ATR = 64B). If a
  response is truncated, enlarge in `tp9k_v2.cpp`.
- **Protocol:** power-on uses EMV mode (`IC_PowerOnEx nMode=2`). If the card is T=1 and mis-reads,
  confirm the vendor's T=0/T=1 handling.
- **PC/SC contention:** don't hold a PC/SC session on the same card while the feeder session is open.
- Capture full stdout for both steps and attach to task-002.5.

## Cross-refs
- Code: `bpr.cpp` commits `96e337b` (transport), `402368e` (--transport factory).
- Planner: rnd-cperso `task-005-tp9000-transport.yaml` + knowledge mem-019.
- This agent: `task-002-tp9000-transport.yaml` (002.5), knowledge mem-001; input
  `01-dendrite/inputs/2026-07-21-tp9000-transport-handoff.md`.
- Vendor API: `bpr.cpp/docs/Specification for Nuvia TPK DLL_4 1 2 5(E)_20240708.doc` (rev 4.1.2.5).
