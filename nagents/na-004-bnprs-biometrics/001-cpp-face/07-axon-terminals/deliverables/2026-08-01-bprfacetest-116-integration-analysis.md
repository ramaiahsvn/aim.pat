# BprFaceTest (.NET) → BprFace 2.24.116 — integration analysis

**App:** `GitRepos2/TRP1001_SbioidS/trp1001.sbioids.face.testapp/BprFaceTest`
(WinForms, .NET Framework 4.7.2, x64 Debug / AnyCPU Release, 6 `.cs` files, direct `DllImport`)
**Target:** `libBprFace.dll` 2.24.116 (from 2.24.115)
**Date:** 2026-08-01 · **Analyst:** na-004/001 cpp-face

---

## 1. Verdict

The video paths are **not at risk from library changes** — no streaming or detection source
changed between the two versions. The app will nevertheless **appear broken on 116**, and in two
places **crash**, for one reason: it passes an empty licence code, which 115 accepted and 116
rejects.

| | |
|---|---|
| Symbols imported by the app | 18 |
| Still exported by 116, unchanged signature | **18 / 18** |
| Video/streaming source files changed 115→116 | **0** |
| Blocking issues | **1** (licence) |
| Conditional issues | **1** (model path, Windows, layout-dependent) |
| Pre-existing latent bugs found | **4** (2 in the video path) |

---

## 2. What actually changed in the library, 115 → 116

Diff of the BprFace scope between the 115 build commit (`db5b27b`, per its `native-manifest.json`)
and 116 (`4276770`) — only three non-script files:

| File | Change | Affects this app? |
|---|---|---|
| `sFace_t12/BprSFace.h` | licence check now honours the caller's bytes | **YES — blocking** |
| `sFace_t12/BprModelPath.h` | Windows module resolution corrected | **Conditional** |
| `cli/…/BprIdFace_dll_exports.cpp` | `BprLicGeneration`/`BprLicVerification` definitions moved to a shared TU | No — ABI identical, app uses neither |

**Untouched:** `BprSFaceDetect.cpp`, `BprSFaceRecog.cpp`, `BprSFaceSmoke.cpp`, `BprSFaceFight.cpp`.
Every streaming, capture, callback, drawing and detection code path is byte-identical to 115. The
frame-callback contract (`data, width, height, stride`, BGR24) is unchanged.

---

## 3. BLOCKING — the empty licence code

`Form1.cs:39-42` initialises all four engines with `""`:

```csharp
bfdHandle = InitializeFaceDetect("",  0.6f, 0.3f, 5000);   // qiCode = "", qiCode.Length = 0
bfrHandle = InitializeFaceRecog("",   0.363, 1.128, 0);
bsdHandle = InitializeSmokeDetect("", 0.5f, 0.45f);
bftHandle = InitializeFightDetect("", 0.5f, 0.45f);
```

116's check fails closed on exactly this (`BprSFace.h`):

```cpp
if (qiCode == nullptr || qiCodeSize <= 0) return false;
```

so all four `*_Init` return `nullptr` and all four handles become `IntPtr.Zero`.

### Consequences, per control

| Control | Guarded by `!= IntPtr.Zero`? | Behaviour on 116 |
|---|---|---|
| `button1` face-detect stream | yes | **silently does nothing** |
| `button6` folder process | yes | silently does nothing |
| `button2` quality | yes | silently does nothing |
| `btnSmokeStream` / `btnSmokeImage` | yes | silently do nothing |
| `btnFightStream` / `btnFightImage` | yes | silently do nothing |
| **`button3` recog image** | **NO** | **access violation** |
| **`button4` recog template** | **NO** | **access violation** |
| `button5` `Bpr_FaceVideo_Streaming` | n/a | **still works** |
| `FormClosing` → 4× `DeInit` | no | safe (`delete nullptr` is well-defined) |

**Why button3/4 crash rather than fail:** they pass the null handle straight through, and
`BprFaceRecog::_face_recog_image` (`BprSFaceRecog.cpp:162`) dereferences it with no null check —
`instance->setInputSize(...)`. The enclosing `catch (const std::exception&)` does **not** catch an
access violation on Windows (SEH, not a C++ exception), so this is a hard crash, not a caught error.

**Why button5 survives:** `Bpr_FaceVideo_Streaming` takes no handle and no `qiCode` and has **no
licence gate at all**. Only the four `*_Init` functions are gated. So the native-window webcam path
keeps working on 116 while the callback-into-PictureBox path stops — an asymmetry that will look
baffling in testing if you don't know to expect it.

### Fix

Supply a real 16-hex-character code. Format (`bpr_lic_main.cpp`): the code decrypts to
`YYYYMMDD` + 4 ASCII product-code characters; **BprFace passes an empty product code**, so only the
expiry date is enforced. `C884C92A9295C92F` — the constant the build's own
`Pat_is_valid_license_global()` uses — is valid today (verified against the shipped 116 binary:
accepted, while garbage/empty/truncated are rejected).

```csharp
private const string QiCode = "C884C92A9295C92F";   // 16 hex chars
...
bfdHandle = InitializeFaceDetect(QiCode, 0.6f, 0.3f, 5000);
```

For anything beyond this test app, get a per-customer code from **na-003/011 bnprs-lib-license**
rather than reusing the build constant — reusing it reproduces the "expiry date on the binary, not
licensing" situation that 116 exists to end.

Note `Bpr_FaceDetect_T12_Init` additionally requires `Pat_is_valid_license_global()` (`&&`); the
other three check only the caller's code.

### Library-side gap worth fixing (na-004/001)

On the failure path `Bpr_*_T12_Init` returns `nullptr` **without writing `*errorCode`**. The app
already passes `ref errorCode` and simply never reads it — but even if it did, it would learn
nothing. A caller cannot currently distinguish "bad licence" from "model missing". Setting a
distinct code here would make this migration self-diagnosing.

---

## 4. CONDITIONAL — Windows model-path resolution flipped

`BprModelPath.h` on Windows used to ask `GetModuleHandleA("BprFace.dll")`. **The DLL is named
`libBprFace.dll`**, so that lookup never matched; it fell through to `GetModuleHandleA(nullptr)` —
the executable — and resolved `bpr.model.onnx` **relative to the EXE directory**.

116 uses `GetModuleHandleExA(…FROM_ADDRESS…)`, the correct analogue of POSIX `dladdr`, which
resolves **relative to the DLL directory**.

- **Same folder (current layout):** the app has no copy step in `BprFaceTest.csproj`; the natives
  and model are dropped manually into `bin\Debug\` beside `BprFaceTest.exe`. EXE dir == DLL dir, so
  **no impact**.
- **If the integration moves natives** into `native\`, `runtimes\win-x64\native\`, or a shared
  install directory — which is the natural thing to do when adopting a NuGet-style layout —
  `bpr.model.onnx` **must move with the DLL**, not stay with the EXE. On 115 the opposite was true.

This is the one change that can bite silently *after* the licence is fixed, so decide the deployment
layout deliberately.

---

## 5. Deployment payload for 116 (Windows x64)

Windows is **not** self-contained. Ship all four together:

```
libBprFace.dll                     ← imports libBprFaceDeps.dll
libBprFaceDeps.dll                 ← OpenCV, split out to keep the main DLL small
opencv_videoio_ffmpeg4100_64.dll   ← videoio; needed by the streaming paths
bpr.model.onnx                     ← resolved relative to libBprFace.dll on 116
```

Omitting `libBprFaceDeps.dll` yields a `DllNotFoundException` at the first P/Invoke that looks like
a missing `libBprFace.dll`. (The 2.24.115 `native-manifest.json` listed only three binaries and
omitted both Windows platforms entirely — do not use it as a packing list. 116's manifest lists all
nine files.)

`PlatformTarget` is x64 for Debug but **AnyCPU for Release** — on a 64-bit OS AnyCPU runs 64-bit so
it happens to work, but pin Release to x64 to match the native.

---

## 6. Pre-existing latent bugs (not introduced by 116)

**(a) Callback delegate can be collected while a native thread holds it — video path.**
`_frameCallback = OnFrame;` allocates a *new* delegate each time and stores it in a single field
shared by the face, smoke and fight streams (`Form1.cs:316, 427, 472`). Start the face stream, then
the smoke stream: the field now roots only the second delegate, while the native face-streaming
thread still calls through the first one's function pointer. Once GC collects it, the next frame
callback jumps into freed memory. Use one field per stream, or a single cached
`static readonly BprFrameCallback`.

**(b) Teardown races the streaming threads — video path.**
`MainForm_FormClosing` calls all four `DeInit` unconditionally while `Bpr_*_Stream` may still be
running on a `Task.Run` thread; `_face_detect_deinit` is `delete instance`. Closing the form
mid-stream deletes an object a native thread is using. `OnFrame`'s `BeginInvoke` will also throw on
a disposed handle. Needs a stop-and-join before `DeInit` — the streaming API has no cancel today,
which is worth raising as a library requirement.

**(c) `size_t` vs `int` on length parameters.**
Native declares `size_t` (8 bytes on x64) for `query_path_len`, `gallery_path_len`,
`imagePathLen`, `service_path_len`, `query_path_len` in `_Process`; the C# side declares `int`.
Arguments landing in registers zero-extend harmlessly. Arguments landing on the **stack** do not:
the marshaller writes 4 bytes into an 8-byte slot and the upper half is not guaranteed zero. In
`Bpr_FaceRecog_T12_Image`, `gallery_path_len` is the 6th integer argument → stack-passed → the
native side does `std::string(gallery_path, gallery_path_len)` with it. It evidently works today,
but it is undefined by the ABI. Fix on the C# side (`UIntPtr`/`nuint`) to avoid an ABI break.

**(d) `bool` marshalling is inconsistent — and this one has teeth.**
Some declarations carry `[MarshalAs(UnmanagedType.I1)]`, others don't —
`Bpr_FaceQuality_T12_Image`, `Bpr_FaceRecog_T12_Image`, `Bpr_FaceRecog_T12_Template`,
`Bpr_FaceDetect_T12_Process`, `Bpr_FaceVideo_Streaming` omit it. Default P/Invoke marshalling for
`bool` is the 4-byte Win32 `BOOL`; native is a 1-byte C++ `bool`.

**On Windows x64 this is benign**, and that is a property of the ABI rather than of the code: every
stack argument occupies a padded 8-byte slot, so a 4-byte `BOOL` written where a 1-byte `bool` is
read still presents the right low byte. Your deployment target is safe.

**It is not portable, and the failure is a hard crash.** Demonstrated 2026-08-01 while testing the
BprCCTV split: a C harness declared `Bpr_FaceDetect_T12_Stream`'s `save_flag`/`vis_flag` as `int`
instead of `bool`. On Apple arm64, stack arguments are packed at natural size — one byte for a
`bool`, four for an `int` — so those two parameters shifted every later stack argument, including
the frame-callback pointer. The library called a garbage address and took `SIGBUS`
(`EXC_ARM_DA_ALIGN at 0xffffffff00000005`). Same mistake, same signature, fatal instead of
harmless, purely because the platform packs rather than pads.

That matters here the moment this app is run on .NET on macOS or Linux ARM. Apply `I1` uniformly
now rather than treating it as cosmetic.

**(e) Dead references.** All 13 `HintPath`s point at `..\BprFaceCpp\packages\`, which does not
exist in this checkout, including `AForge.Video.DirectShow` — and **no `.cs` file references
AForge**. The app's video is entirely native (callback + `Bpr_FaceVideo_Streaming`). Removing these
would make the project restore cleanly, and confirms there is no managed video stack to disturb.

---

## 7. Recommended migration order

1. **Licence first, alone.** Add the `qiCode` constant, change the four `Form1_Load` calls, run
   against the **current 115** DLL. It must still work — 115 ignores the code, so this isolates the
   change.
2. **Read `errorCode` and null-check the handles.** Add `IntPtr.Zero` guards to `button3`/`button4`
   and surface a message when `Form1_Load` fails, so step 3 reports rather than crashes.
3. **Swap in 116** with all four Windows files, model beside the DLL.
4. **Verify in this order:** `button5` (ungated — proves the DLL loaded and the camera works
   independently of licensing), then `button2`, then `button1` callback streaming, then
   `button3`/`button4`.
5. **Then** the latent fixes (a)–(d), which are independent of the version bump.

Steps 1–2 are the only changes needed to make 116 behave; 3–4 are verification.

---

## 8. Uniformity note (BprIDEngine)

This app is a direct consumer of the **legacy per-modality entry points**
(`Bpr_FaceRecog_T12_*`, `Bpr_FaceDetect_T12_*`, …), not of the generalised `BprID_*` ABI. The two
are separate surfaces on separate libraries: `BprID_*` is parameterised by TID/MID
(`id = (modality << 8) | variant`) and is licence-gated once via `BprID_SetLicense`, whereas each
`Bpr_*_T12_Init` here carries its own `qiCode`. Migrating this app to `BprIDEngine` would collapse
the four handles and four licence calls into one — but **`BprIDEngine` has no streaming/video
surface**: it covers extract / match / quality / fuse only. The video functionality this app is
built around has no `BprID_*` equivalent today, so a migration would have to keep `libBprFace.dll`
for streaming regardless. Recommend staying on the T12 entry points for this app — see §9 for what happens if the
library is moved to a generic-only surface.

---

## 9. Impact if the libraries expose ONLY the generic `BprID_*` methods

**Question posed 2026-08-01:** the intent is to expose only the generalised methods
(`BprID_Extract`, `BprID_Match`, …) across every modality *and its library*. Does that affect this
sample?

**Answer: it does not degrade it — it deletes it.** All 18 of the app's imports disappear. The
first P/Invoke (`Form1_Load:39`) throws `EntryPointNotFoundException` and the window never opens.

This is measured, not inferred. bengine's per-modality `libBprFace` was inspected directly:

```
$ nm -gU src/BprIDEngine/bengine/build-all/libBprFace.dylib
  21 × BprID_*  +  BprLicGeneration  +  BprLicVerification
  legacy Bpr_Face* / Bpr_Smoke* / Bpr_Fight* symbols:  0
```

The two surfaces are **completely disjoint**. There is no overlap to migrate through.

### Coverage of this app's 18 imports

| App operation | Generic equivalent |
|---|---|
| `Bpr_FaceQuality_T12_Image` | `BprID_Quality` ✅ |
| `Bpr_FaceRecog_T12_Image` | `BprID_Extract` ×2 + `BprID_Match` ✅ (reshaped — no image-vs-image call) |
| `Bpr_FaceRecog_T12_Template` | `BprID_Match` ✅ |
| 4 × `*_T12_Init` | collapse into one `BprID_SetLicense` — **but tuning is lost, below** |
| 4 × `*_T12_DeInit` | not needed — the generic ABI has no handles |
| `Bpr_FaceDetect_T12_Stream` | ❌ none |
| `Bpr_FaceDetect_T12_Process` | ❌ none |
| `Bpr_FaceVideo_Streaming` | ❌ none |
| `Bpr_SmokeDetect_T12_Stream` / `_Image` | ❌ none |
| `Bpr_FightDetect_T12_Stream` / `_Image` | ❌ none |

**3 of 18 map cleanly. 7 have no equivalent — and they are precisely what this app exists to
demonstrate.**

### Why those 7 are not a gap to be filled later

Three structural reasons, not outstanding work:

1. **Smoke and fight detection are not biometrics.** They yield no template, identify no person,
   and have no probe/gallery pair. `Extract → Match` cannot express "how many smoke regions are in
   this frame". Forcing them into a modality-generic *biometric* ABI would corrupt the abstraction
   that makes it worth having.
2. **The generic ABI is stateless and still-image.** `BprIDSample` carries pixels or a path — one
   sample, one call. `grep -ciE "callback|stream|video|camera|frame" bprid_abi.h` returns **0**.
   There is no session, no frame loop, no callback type. Streaming is not an operation to add; it
   is a different execution model.
3. **Per-engine tuning has nowhere to go.** `conf_threshold`, `nms_threshold`, `topK`,
   `enableTemplateExtraction`, `cosine_threshold`, `norm2_threshold`, `dist_type` are constructor
   arguments to the four handles. `BprID_Extract(tid, sample, out, io_size)` takes no configuration
   at all — that uniformity is the point of the design, and it is why those knobs cannot survive
   the move.

### Recommendation — two surfaces, deliberately

| Library | Surface | Owns |
|---|---|---|
| standalone **BprFace** 2.24.116 (bpr.cpp root build) | legacy `Bpr_*_T12_*` | video, streaming, smoke, fight, folder batch — **this app** |
| bengine per-modality **BprFace** + **BprIDEngine** | `BprID_*` only | template extract / match / quality / fuse |

"Generic methods only" is right **for the biometric template operations**. Applied to the whole
library it removes the video product. This sample should stay on the T12 surface; no change to it
is implied by the generic-ABI direction.

### This sharpens the naming collision — settle it before publishing

Two different libraries already build as `libBprFace` with **disjoint ABIs**. If both ever ship
under the name `BprFace`, a consumer resolving that name gets one of two incompatible things
depending on provenance, and **registry versions are immutable** so it cannot be undone by
re-uploading. This is the precondition already recorded against the deferred per-modality publish
(cpp-bengine `mem-036`, and the "PLANNED, NOT YET PUBLISHED" block in lib-forge `libraries.yaml`);
the generic-only direction makes it the blocking decision rather than a future tidy-up.

Options, for na-004/007 + na-002 to choose between:
- rename the bengine per-modality output (e.g. `BprIDFace`, or `BprIDEngine.Face` as the wrapper
  variants already do), keeping `BprFace` for the product line; or
- keep `BprFace` for the bengine output and rename the legacy video library; or
- never publish the per-modality libraries at all and expose only the consolidated `BprIDEngine`,
  which sidesteps the collision entirely.
