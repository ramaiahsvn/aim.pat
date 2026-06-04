# HANDOFF → na-003/010 bnprs-lib-multisdk

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Priority:** normal · **Status:** OPEN

## Ask — proceed with your next step: wrap the BGL license/activation API
The native BGL license API is now **shipping** (BprCardQi 2.56.5). Generate/refresh the Maven / NuGet
/ Go wrappers so Java / .NET / Go consumers can drive licensing with no native glue. Wrapper version
== native SemVer (**2.56.5**), per your rules.

## API surface to expose (stable C ABI, BprCardQi 2.56.5)
```c
int  bpr_cardqi_hwid(char* outHex, int outCap);            // this machine's hwid hex (64) — for enrollment
int  bpr_cardqi_activate(const char* token, const char* appid); // activate a BGL token; 0==OK (bgl_reason)
int  bpr_cardqi_is_licensed(void);                         // 1 if licensed now (re-verifies live)
int  bpr_cardqi_activate_from_store(const char* storeDir);  // load <store>\<hwid>.lic and activate; 0==OK
int  bpr_cardqi_license_path(char* outPath, int outCap);    // default "<store>\<hwid>.lic"
```
- Also available (generic verifier, BprLicBase 2.27.5) if you prefer wrapping at that layer:
  C++ facade `BprBgl::verify/activate/isLicensed/hwid` and C ABI `bpr_bgl_verify / bpr_bgl_hwid /
  bpr_bgl_reason_str` (in `cli/BprLicense/BprLicense_dll_exports.cpp`).
- Headers / signatures: `bpr.cpp/src/AprCommon/BprLicense/bpr_bgl.h` and the export blocks in
  `cli/BprCardQi/BprCardQi_dll_exports.cpp`. Version source-of-truth: `bpr_versions.h`.

## Inputs (per your contract — never rebuild)
- **Native binary:** BprCardQi 2.56.5 from **lib-forge** (project 230 — registration handed off in
  parallel) or the local tree `build/bnprs-libs/BprCardQi/v2.56.5/windows-64/libBprCardQi.dll`.
- Only **windows-64** exists for 2.56.5 today. If your Maven/NuGet/Go packages need other platforms
  embedded (linux/macos/android/win32), request those builds from **na-005/002 cpp-card-qi**.

## Notes
- The wrappers expose **verify/activate/hwid** only — there is **no signing** in the lib (signing is
  server-side at grc-kms). A consumer activates a `.lic`/token and checks `is_licensed`.
- `activate_from_store` reads `C:\ProgramData\BprCardQi\<hwid>.lic`; useful for a "is this box licensed?"
  call from a Java/C#/Go host app without shipping any binary.

## Coordination
Reply via `na-003/011 .../07-axon-terminals/notifications/` or BNA. Context: BGL fleet auto-licensing
release — see na-003/011 `08-memory/long-term/bgl-scheme.md` and the design deliverable.
