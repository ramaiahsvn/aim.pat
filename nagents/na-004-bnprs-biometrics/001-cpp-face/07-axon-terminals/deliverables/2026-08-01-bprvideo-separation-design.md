# Design note — separating BprVideo from the per-modality libraries

**Status:** proposal, for na-004/001 + na-004/007 + na-002 to accept or reject
**Date:** 2026-08-01 · **Author:** na-004/001 cpp-face
**Origin:** user proposal — "separate video, streaming, smoke, fight, folder batch functions into a
different folder like BprVideo and its library BprVideo, keeping per-modality features separate"
**Related:** `2026-08-01-bprfacetest-116-integration-analysis.md` §9 (why generic-only deletes the
video product), cpp-bengine `mem-036` / `mem-037`

---

## 1. Recommendation in one line

**Do it — but as a three-way layered split with an analyser hook, not a two-way move of functions.**
The seam is *transport vs analysis*, not *video vs face*.

---

## 2. What the code actually supports

Measured, not assumed:

| Finding | Evidence |
|---|---|
| Smoke/fight have **zero** face coupling | `grep -c "BprFaceDetect\|BprFaceRecog\|FaceObj"` = **0** in both files |
| Models partition cleanly across the proposed line | m10001–m10004 face · m10005 smoke · m10006 fight |
| The capture loop is **triplicated** | three near-identical `VideoCapture` + `cap >> frame` loops in Detect/Smoke/Fight |
| A shared camera helper already exists | `BprTryOpenCamera` in `BprSFace.h:43` |
| Smoke/fight are not *inherently* video | both expose `_Image` entry points that run on one file |

Current sizes: `BprSFaceDetect.cpp` 1120 · `BprSFaceFight.cpp` 338 · `BprSFaceSmoke.cpp` 307 ·
`BprSFaceRecog.cpp` 302 · `BprSFace.h` 409.

### The blocker for a naive split

`Bpr_FaceDetect_T12_Stream` is **capture loop + face detector in one function**. It cannot move
wholly into `BprVideo` (it needs the face engine) and cannot stay wholly in `BprFace` (it is a
capture loop). Any "move these functions" split stalls here. The layered split does not.

### The common loop, extracted

Every one of the three streams is this, differing only in the marked block:

```
BprTryOpenCamera(cap, url)
while (true):
    cap >> frame;  if (frame.empty()) break
    throttle (>= 1.0 s since last)
    ──── ANALYSE + ANNOTATE ─────────  ← the ONLY per-domain part
    if (save_flag && hit)  imwrite(destFolder/<timestamp>.png, output)
    if (vis_flag && !frameCallback)  imshow(title, output)
    if (frameCallback)  frameCallback(output.data, cols, rows, step)
    if (vis_flag && !frameCallback && waitKey(1) == 27) break
```

---

## 3. Proposed structure

```
src/BprVideo/                     → libBprVideo      transport only, NO models
    BprVideoCapture.{h,cpp}         open/retry, frame loop, throttle, restart-after-N
    BprVideoSink.{h,cpp}            timestamped save, imshow/ESC, frameCallback dispatch
    BprFrameAnalyser.h              the hook (below)
    BprVideoFolder.{h,cpp}          folder batch — same analyser over a directory

src/BprIDEngine/BprFace/          → libBprFace       BIOMETRIC only
    sFace_t12/BprSFaceDetect.cpp    detection, minus the streaming loop
    sFace_t12/BprSFaceRecog.cpp     unchanged
    sFace_t12/BprSFaceExpres.cpp    unchanged
    models: m10001..m10004

src/BprVision/                    → libBprVision     NON-biometric detectors
    BprSmokeDetect.{h,cpp}          from BprSFaceSmoke.cpp
    BprFightDetect.{h,cpp}          from BprSFaceFight.cpp
    BprYoloDetector.{h,cpp}         shared base, from BprSFace.h:259
    models: m10005, m10006
```

### The hook

`BprVideo` depends on neither analyser library; they depend on it (or on a tiny shared header).

```cpp
// BprVideo/BprFrameAnalyser.h — the entire coupling surface
class IBprFrameAnalyser {
public:
    virtual ~IBprFrameAnalyser() = default;
    // Analyse `in`, draw onto `out`. Return true if something of interest was found —
    // BprVideo uses that, not the analyser, to decide whether save_flag writes a frame.
    virtual bool process(const cv::Mat& in, cv::Mat& out) = 0;
};
```

`BprFace` supplies a face analyser, `BprVision` supplies smoke and fight analysers. The existing
`Bpr_FaceDetect_T12_Stream` becomes `BprVideo`'s loop driven by `BprFace`'s analyser — composed in
a thin glue layer or by the host.

### Why three libraries, not two

Smoke and fight are **not video**. `Bpr_SmokeDetect_T12_Image` and `Bpr_FightDetect_T12_Image` run
on a single file with no camera involved. Filing them under `BprVideo` would mislabel them and the
mistake resurfaces the first time someone wants smoke detection on a still image. They are
non-biometric *detectors* that can optionally be driven by a stream — which is exactly what the
analyser hook expresses.

---

## 4. Costs — decide these before starting

### 4.1 OpenCV payload triples on POSIX — the significant one

`libBprFace.dylib` is 16 MB, self-contained, static OpenCV. That self-containment was built
deliberately for 2.24.115 to unblock the multi-SDK wrappers (multisdk `mem-005`). Three
self-contained libraries means three copies of OpenCV: **~48 MB instead of 16 MB**.

Windows already avoids this — `libBprFace.dll` is 16 MB and imports a shared 52 MB
`libBprFaceDeps.dll`. Extending that model gives one `BprDeps` for all three.

| Option | POSIX size | Keeps self-contained? |
|---|---|---|
| three static libraries | ~48 MB | yes |
| shared `libBprDeps.{so,dylib}` + three thin libraries | ~16 MB + 3 small | **no** |
| keep one library, split only the *source folders* | 16 MB | yes |

The third option is worth naming explicitly: **the folder/source separation delivers most of the
architectural benefit at zero packaging cost.** Splitting the *binaries* is what costs. If the goal
is "keep per-modality features separate" for clarity and ownership, do the source split first and
treat the library split as a separate decision with the wrapper/packaging implications weighed in.

### 4.2 Model blob fragments

`bpr.model.onnx` becomes 2–3 blobs. Since 2.24.116 resolves models **per-module**
(`GetModuleHandleExA(FROM_ADDRESS)` / `dladdr`), **each blob must sit beside its own library** —
`BprVision`'s blob next to `libBprVision`, not next to the executable. Deployment gains files, and
the layout is now load-bearing rather than incidental.

### 4.3 ABI break for existing consumers

The .NET sample imports 18 symbols; **7 move** (`Bpr_FaceDetect_T12_Stream`, `_Process`,
`Bpr_FaceVideo_Streaming`, `Bpr_SmokeDetect_T12_Stream`/`_Image`,
`Bpr_FightDetect_T12_Stream`/`_Image`). Sequence this **after** the 2.24.116 licence migration is
done and verified — never in the same step, or a failure cannot be attributed.

### 4.4 Version ranges need a decision

`bpr_versions.h` reserves 6xx–8xx for future **modality** libraries; BprIDEngine took 9xx precisely
to stay out of that run because it is not a modality. `BprVideo` and `BprVision` are also not
modalities. They need either their own `MAJOR.MINOR` lines (like BprCardQi 2.56.x, BprCardEmv
2.57.x) or a documented carve-out. **Recommend separate MAJOR.MINOR lines** — it keeps the 2.24.x
biometric line meaning "biometric".

---

## 5. The strategic prize

This resolves the `BprFace` name collision **by elimination**.

Two libraries currently build as `libBprFace` with disjoint ABIs: the standalone product (legacy
`Bpr_*_T12_*`, owns video) and bengine's per-modality output (`BprID_*` only). That collision is
the recorded blocker on publishing the per-modality libraries (cpp-bengine `mem-036`), and §9 of
the integration analysis made it the blocking decision rather than a future tidy-up.

If video, smoke and fight leave, what remains in the standalone `BprFace` is **detect / recog /
quality** — precisely what bengine's `BprFace` covers via `BprID_*`. The two stop being
incompatible things fighting over a name and become candidates to converge on one library with one
ABI. That is a better outcome than renaming either.

---

## 6. Suggested sequence

1. **Finish the 116 migration** on the .NET sample (licence + null guards). Do not start this work
   until that is verified — it is the only way to attribute a later regression.
2. **Source-folder split only**, one library still. Extract the common loop into
   `BprVideoCapture`/`BprVideoSink`, introduce `IBprFrameAnalyser`, move smoke/fight/YOLO out of
   `BprSFace.h` into `BprVision` sources. **No ABI change, no packaging change, no version bump
   beyond a patch.** De-triplicating the capture loop is a net win on its own.
3. **Decide the packaging question** (§4.1) with the wrapper and deployment cost in front of you,
   now that the source boundaries are real and the diff is small.
4. **Only then** split binaries, if step 3 says so — with new version lines, per-library model
   blobs, and a consumer migration note.

Step 2 is safe, reversible and independently valuable. Steps 3–4 are the ones that cost.

---

## 7. Open questions for the owners

- Library names: `BprVision` for smoke/fight? Alternatives: `BprScene`, `BprSafety`,
  `BprObjectDetect`. It should not say "face" and should not say "video".
- Does `BprVideo` get a public C ABI of its own (a host drives capture and supplies an analyser),
  or does it stay an internal static library that the modality libraries link? The former is more
  useful and more work.
- Who owns `BprVision`? It is not a biometric modality, so na-004 may not be the right home.
- Does the folder-batch path (`Bpr_FaceDetect_T12_Process`) belong to `BprVideo` at all? It reads a
  directory of stills — arguably it is a *driver*, like streaming, so yes, but it is worth stating
  rather than assuming.
