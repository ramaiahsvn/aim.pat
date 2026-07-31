# BprIDEngine 2.24.900

Released 2026-07-31. Source: `bpr.cpp` @ `ddbb211`.

The consolidated biometric engine: **one library, six modalities, one C ABI**. Face, finger,
fingerprint-contactless, finger-knuckle, palmprint and iris all sit behind the same 21 `BprID_*`
functions, so adding a modality never changes the interface a host compiles against.

## What is in this folder

```
include/bprid_abi.h          the ABI — the only header a host needs
hosts/java/                  working Java integration + sample (see its README)
verify-windows/              one-minute Windows self-test (see WINDOWS below)
lean/<platform>/             the lean native
t12/<platform>/              the face-T12 native
t12/models/                  the three ONNX models T12 needs
```

Platforms: `linux-x86-64`, `linux-aarch64`, `darwin-arm64`, `windows-64`, `windows-32`.
No `windows-arm64` — there is no aarch64 mingw toolchain on the build host.

## Two variants — pick one, never both

| | lean | t12 |
|---|---|---|
| size | ~370 KB | ~17 MB + 46 MB models |
| face T12 extract / match / quality | **no** | yes |
| everything else (T21, T31, T33, T41, T51, M11 …) | yes | yes |
| OpenCV | none | statically linked |

Both export the **same 21 symbols** under the **same library name**. Deploying both into one
process — or putting both packages on one classpath — leaves it undefined which loads. The split
exists because face T12 is the only modality that costs anything; a host that never enrols a face
should not carry 120× the size for it.

The lean build still *matches* faces (M11, a cosine over a pat-produced T11 vector). What T12 buys
is *enrolment* — turning an image into a template — plus the only quality assessor in the engine.

## Deployment

**The T12 models must sit in the same directory as the native.** The engine resolves them relative
to its own library via `dladdr`, not relative to the working directory. Copy `t12/models/*.onnx`
beside `libBprIDEngine.so`. They are identical for every platform, which is why they are stored
once here rather than duplicated per folder.

The lean native has no models and no external dependencies at all.

## WINDOWS

The DLL is named **`libBprIDEngine.dll`** — the `lib` prefix is mingw's and matches the other
libraries on this share. P/Invoke and `LoadLibrary` need that exact name, so either keep it or
rename the file and the reference together.

**Self-contained.** It imports nothing but `KERNEL32`, `VERSION` and the universal CRT
(`api-ms-win-crt-*`), all of which ship with Windows. In particular it does **not** need
`libstdc++-6.dll`, `libgcc_s_seh-1.dll` or `libwinpthread-1.dll` — those are statically linked in.
Do not ship mingw runtime DLLs alongside it; if an older copy is on the path it will not be used.

**Export surface differs slightly from ELF, in Windows' favour:**

| | windows | linux |
|---|---|---|
| `BprID_*` | 20 | 21 |
| `BprLicGeneration` / `BprLicVerification` | yes | no |
| `BprID_LibraryNameImpl` | no (correct — internal) | yes (leaks) |
| FJFX + STL symbols | no | yes (~22 leak) |

Two of those are ELF bugs rather than Windows omissions: `BprID_LibraryNameImpl` is an internal
helper behind `BprID_LibraryName` and should not be public anywhere, and the FJFX/STL symbols leak
out of the `.so` because the shared target does not carry the hidden-visibility preset its static
inputs do. Both are logged against na-004/007 and neither changes behaviour — but a caller writing
against "whatever the library exports" rather than `bprid_abi.h` will see a different list per
platform. Write against the header.

**The T12 DLL additionally exports the five legacy BprFace entry points** — `Bpr_FaceRecog_T12_Init`,
`_DeInit`, `_Image`, `_Template` and `Bpr_FaceQuality_T12_Image` — because `BPR_FACE_EXPORT` is
`__declspec(dllexport)` on Windows and empty elsewhere. That is an accident of the macro, not a
design decision, but it is useful: an existing Windows .NET caller can keep its current P/Invokes
working while it migrates to `BprID_*`, rather than having to switch in one step. Treat them as
deprecated — they are absent on every other platform and carry the old licence path.

**Verification status — read before deploying T12.**

*lean:* fully verified. Loads, reports `2.24.900`, the capability set is correct
(T21/T33/T41/T51 present, T12 absent), and a bad licence is rejected.

*t12:* verified for **load and ABI only** — it loads, resolves all 27 exports, accepts a licence
and extracts a correct 528-byte template. Its **numeric results are NOT verified**: the only
Windows environment available was wine under x86-64 emulation on Apple Silicon, where the OpenCV
path returned quality `0.0` and a self-match of `0.0`. A self-match of 0.0 is impossible for a
valid template, and wine raised an AVX-state assertion, so emulated SIMD is the likely cause — the
Linux T12 build returns the correct `raw=25` under the same emulation without wine. That is an
argument, not a measurement.

**Run `verify-windows/` on a real Windows machine before trusting Windows face scores.** It takes a
minute and prints the expected values to compare against. Until then, treat Windows T12 as
unproven; Windows lean and every non-Windows platform are unaffected.

## Prefer the packages over these binaries

For Java, .NET and Go, consume the published packages instead — they embed the native and the
models and stage them correctly at load, so the directory rule above is handled for you:

| | lean | t12 |
|---|---|---|
| Maven | `ai.bnprs:nativesdk-bpridengine:2.24.900` | `ai.bnprs:nativesdk-bpridengine-face:2.24.900` |
| NuGet | `Bnprs.NativeSdk.BprIDEngine 2.24.900` | `Bnprs.NativeSdk.BprIDEngine.Face 2.24.900` |
| Go | `…/go/bpridengine/v2 v2.24.900` | `…/go/bpridengine-face/v2 v2.24.900` |

All from GitLab project 230 (`BPR1000/bpr1000.bnprs-libs`). The raw binaries here are for C/C++
hosts and for anyone who needs to deploy without a package manager.

### "Dependency not found" is an auth failure

The registry is private, so an unauthenticated request returns **401** — and every client then
reports it as *missing*: Maven marks the artifact `(absent)`, IntelliJ says *"Dependency
ai.bnprs:nativesdk-bpridengine-face:2.24.900 not found"*, NuGet says the package does not exist.
The artifact is there. Check credentials before looking for anything else.

The header depends on which kind of token you have, and the wrong one gives the same 401:

| token type | Maven / NuGet header | value |
|---|---|---|
| personal access token (`read_api`) | `Private-Token` | the token |
| deploy token (`read_package_registry`) | `Deploy-Token` | the token value, **not** the username |

The read-only deploy token is `bnprs-libs-readonly` (username `bnprs-libs-ro`) and it is defined on
the **group** `BPR1000`, not on project 230 — group scope covers the project. Its value is shown
once at creation and cannot be retrieved through the API afterwards; mint a new one rather than
searching for it.

After fixing credentials, clear the cached failure or the old error persists:
`rm -rf ~/.m2/repository/ai/bnprs/nativesdk-bpridengine-face && mvn -U …`.
Full walkthrough, including the IntelliJ settings-file override: `hosts/java/README.md`.

## Licensing

`BprID_SetLicense(qiCode, len)` must be called and must succeed before `Extract`, `Match`,
`Quality` or `Fuse`. The code is **caller-supplied** and re-validated on every call, never cached,
so a licence that expires mid-process stops working immediately.

`BprID_Version`, `BprID_LibraryName` and the status/name helpers need no licence — a host can
always identify the binary and render an error before it is licensed.

## Capability detection

Ask the binary rather than inferring from which file you shipped:

```c
BprID_HasTemplate(tid)   BprID_HasMatcher(mid)   BprID_HasQuality(tid)
```

`tid` is `(modality << 8) | variant`; face T12 is `0x4A02`. Three failure statuses are kept
distinct because they need different fixes:

| status | meaning | fix |
|---|---|---|
| `NOT_PRESENT` (-2) | the id is not in this binary | you deployed the lean variant |
| `NOT_IMPL` (-3) | extractable, but no quality assessor | none — only T12 has one today |
| `NOT_REGISTERED` | unknown id | wrong id or a bad encoding |
| `LICENSE` (-8) | no valid licence | call `BprID_SetLicense` |

## Verified behaviour

Identical through the native, Java, .NET and Go on `linux/amd64` — the binding does not change the
answer:

```
T12 quality  normalized = 0.2580570578575134   raw = 25
T12 template 528 bytes
M12 self-match 0.9999999963022734
T21 quality  not-implemented
```

`Quality.raw` is the 0-100 integer `Bpr_FaceQuality_T12_Image` returned, so a caller migrating off
the legacy BprFace API keeps its existing threshold unchanged.

## Migrating off BprFace

Four behavioural breaks — see `hosts/java/README.md` for the full call mapping and a worked
example:

1. **`qiCode` is mandatory.** The legacy `Bpr_FaceRecog_T12_*` accepted an empty string; this does
   not.
2. **`.t12.yml` templates are unreadable.** Legacy templates are OpenCV `FileStorage` YAML read
   from a path; these are 528-byte binary records passed as bytes. Re-enrol or convert.
3. **Scoring no longer enrols.** `Bpr_FaceQuality_T12_Image(save_flag: true)` also wrote a
   template as a side effect. `BprID_Quality` only scores; call `BprID_Extract` for the template.
4. **No image-vs-image compare.** Extract both, then match — and in a loop, extract the gallery
   side once and reuse it.

Thresholds carry over unchanged: on cosine (`dist_type 0`, the default) `BprID_Match`'s normalised
score is the legacy `similarityScore`, and quality's `raw` is the legacy integer.

## Version numbering

`2.24.900`. The **900 band is the consolidated engine**; 600–899 is reserved for per-modality
releases. Registry versions are immutable, so any fix ships as `2.24.901`.

## Known gaps

- **Windows T12 numerics are unverified** — see WINDOWS above and run `verify-windows/`.
- No `windows-arm64` (no aarch64 mingw toolchain on the build host).
- The Maven / NuGet / Go packages carry the Linux and macOS natives only, so **they do not run on
  Windows** — and each loader additionally picks the wrong filename there (`libBprIDEngine.so`
  rather than the DLL). Compiling on Windows is unaffected; only executing is. Folding the Windows
  DLLs into the packages needs a new version, since published versions are immutable — 2.24.901.
  Not built: the current consumer builds on Windows and deploys to Linux, which needs nothing.
- The `.so` leaks ~30 non-ABI symbols (FJFX, STL, `BprID_LibraryNameImpl`) that the `.dll` does not.
- Only T12 has a quality assessor; every other modality returns `NOT_IMPL` from `BprID_Quality`.
- There is no T11 extractor — pat's capture device produces those; the engine only matches them.
- Accuracy has been verified for self-match and format correctness, not against a labelled corpus.
