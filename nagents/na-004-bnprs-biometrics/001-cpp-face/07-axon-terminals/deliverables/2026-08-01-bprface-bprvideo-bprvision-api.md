# API specification — BprFace 2.24.117 · BprVideo 2.60.0 · BprVision 2.61.0

**Status:** pre-publication review. Every symbol below was read out of the built artifact with
`nm`, not from a header — the two disagreed before (2.24.116 declared two functions it did not
define), so this document reflects what the binaries actually export.

**Date:** 2026-08-01 · `bpr.cpp` @ 020533b

---

## 0. What each library is for

| library | version | exports | audience |
|---|---|---|---|
| **BprFace** | 2.24.117 | 30 | client — face biometrics + face-over-video |
| **BprVideo** | 2.60.0 | 3 | client — camera transport, no models, no detectors |
| **BprVision** | 2.61.0 | 10 | client — smoke and fight detection (not biometrics) |
| *(BprIDEngine* | *2.24.902* | *30* | *server — all six modalities, same generic ABI)* |

> ### ⚠ Load exactly ONE of these per process
> They share symbols by design, so a host that loads two gets an undefined winner while both
> report plausible versions. `Bpr_FaceVideo_Streaming` is in all three; the eight smoke/fight
> entry points are in BprVision and BprIDEngine. Pick the one library that covers your needs.

---

## 1. BprFace 2.24.117 — 30 exports

**BREAKING vs 2.24.116.** Sixteen exports are gone: `Bpr_FaceRecog_T12_{Init,DeInit,Image,
Template}`, `Bpr_FaceQuality_T12_Image`, `Bpr_Face_Matching_T11`, `bpr_face_get_version`, the eight
smoke/fight entry points and `Bpr_FaceVideo_Streaming`. Template work moves to the generic ABI;
smoke/fight move to BprVision; raw video moves to BprVideo. 2.24.115/116 were deleted from the
registry, so there is no released version to upgrade from.

### 1.1 The generic ABI — 22 symbols, identical to BprIDEngine

```c
/* licensing — MUST come first; Extract, Match, Quality and Fuse are gated */
int  BprID_SetLicense(const char* qiCode, uint32_t qiCodeSize);   /* 0 == OK */
int  BprID_HasLicense(void);                                      /* 1 or 0; re-validates */

/* operations */
int  BprID_Extract (BprIDTemplateId tid, const BprIDSample* sample,
                    uint8_t* out_template, uint32_t* io_size);
int  BprID_Match   (BprIDMatcherId  mid, const uint8_t* probe,   uint32_t probe_len,
                                          const uint8_t* gallery, uint32_t gallery_len,
                    double* out_score, int32_t* out_raw);
int  BprID_Quality (BprIDTemplateId tid, const BprIDSample* sample,
                    double* out_score, int32_t* out_raw);
int  BprID_Fuse    (const double* scores, const double* weights, uint32_t count,
                    int rule, double* out_score);
int  BprID_Preload (BprIDTemplateId tid);   /* load the model NOW — see §1.4 */

/* capability discovery — ungated, answer without a licence */
int  BprID_HasTemplate(BprIDTemplateId), BprID_HasQuality(BprIDTemplateId),
     BprID_HasMatcher(BprIDMatcherId);
int  BprID_ListTemplates(uint16_t* out, uint32_t* io_count);
int  BprID_ListMatchers (uint16_t* out, uint32_t* io_count);
int  BprID_MatcherAccepts(BprIDMatcherId, uint16_t* out, uint32_t* io_count);

/* naming — ungated */
const char* BprID_TemplateName(BprIDTemplateId);
const char* BprID_MatcherName (BprIDMatcherId);
const char* BprID_ModalityProduct(uint8_t modality);
const char* BprID_StatusName(int status);
const char* BprID_Version(void);        /* "2.24.902" — the ENGINE version, see §1.6 */
const char* BprID_LibraryName(void);    /* "BprFace" */
const char* BprID_LibraryNameImpl(void);/* POSIX only — absent on Windows */
const char* BprID_IdToString(uint16_t id, int isMatcher, char* buf, int buflen);
int         BprID_IdFromString(const char* text, uint16_t* outId, int* outIsMatcher);
```

### 1.2 The sample struct — field order matters

```c
typedef struct {
    uint8_t        modality;   /* 0x4A for face — MUST match the TID */
    const uint8_t* bytes;      /* 8bpp grey, tightly packed unless stride says otherwise */
    uint32_t       bytes_len;
    int32_t        width, height, stride;   /* stride 0 == tightly packed */
    uint16_t       dpi;        /* minutiae extractors only; 0 == unset */
    const char*    path;       /* for algorithms that read from disk */
} BprIDSample;
```

Getting the layout wrong fails silently: `path` lands at the wrong offset and every call returns
`-5`. Set `modality` first and always.

### 1.3 Registered ids in this build

```
extractors:  0x4A02  sFace
matchers  :  0x4A01  sFace (pat-cosinesimilarity)
             0x4A02  Yunet+sFace (opencv)
```

TID/MID = `(modality << 8) | variant`. Face is `0x4A`. A T12 template is **528 bytes** — query it
with a NULL buffer rather than hardcoding, since it is a property of the model.

### 1.4 Two-call protocol and readiness

```c
uint32_t n = 0;
BprID_Extract(0x4A02, &s, NULL, &n);   /* returns BPRID_ERR_BUFFER (-4), n = required size */
uint8_t* buf = malloc(n);
BprID_Extract(0x4A02, &s, buf, &n);    /* n = ACTUAL record length on exit, may be shorter */
```

**Use `BprID_Preload`, not `BprID_HasTemplate`, as your readiness check.** `HasTemplate` answers
"is this compiled in" and always returns 1 for T12 here. `Preload` answers "is this usable" and
returns `-7` when the ONNX models are not deployed. Call it once at startup after `SetLicense`; it
also moves the ~170 ms first-call model load off your first request.

### 1.5 Status codes

| | | | |
|---|---|---|---|
| `0` OK | `-1` argument | `-2` not present | `-3` not implemented |
| `-4` buffer (size in `*io_size`) | `-5` input rejected | `-6` probe/gallery TID mismatch | `-7` module failed |
| `-8` no licence | | | |

`BprID_StatusName()` renders any of these and needs no licence — so a startup banner can report
*why* a licence was rejected.

### 1.6 Legacy extension — 8 symbols

Streaming stays outside the generic ABI because that ABI is stateless and still-image: one sample
per call, no session, no frame loop. Face is the only modality with a live-video product, so it
extends past the generic set rather than bending it.

```c
long  Bpr_GLog_Init(void);

int*  Bpr_FaceDetect_T12_Init(char* qiCode, size_t qiCodeSize,
          float conf_threshold, float nms_threshold, int top_k,
          bool enableTemplateExtraction, int* retStrLen, int* errorCode);
void  Bpr_FaceDetect_T12_DeInit(int* instance, int* retStrLen, int* errorCode);

void  Bpr_FaceDetect_T12_Stream(int* instance,
          const char* camSerialNumber, int camSerialNumberLen,
          const char* cameraUrl, int cameraUrlLen,
          int hdWidth, int hdHeight, int scaleFactor,
          bool save_flag, bool vis_flag,
          int distThr, int qltyThr, int saveInterval,
          BprFrameCallback frameCallback, int* retStrLen, int* errorCode);

void  Bpr_FaceDetect_T12_Process(int* instance,
          const char* camSerialNumber, int camSerialNumberLen,
          const char* query_path, size_t query_path_len,
          int scaleFactor, bool vis_flag, int distThr, int qltyThr,
          int* retStrLen, int* errorCode);

void  Bpr_FaceRecog_T11_CosineSimilarity(const char* query_t11,   size_t query_t11_len,
                                         const char* gallery_t11, size_t gallery_t11_len,
                                         double* similarityScore, int* errorCode);

bool  BprLicGeneration(void);                                  /* always false — see below */
bool  BprLicVerification(char* qiCode, size_t qiCodeSize);
```

`BprLicGeneration` returns `false` unconditionally: the two legacy implementations had diverged and
neither was shippable. `BprLicVerification` validates the caller's bytes and fails closed on null,
empty or garbage. Both are standard across the whole family, including BprIDEngine.

**Emission changed.** `Bpr_FaceDetect_T12_Stream` used to invoke `frameCallback` **once per
detected face** — an N-face frame produced N callbacks with progressively-drawn overlays, only the
last complete. It now fires **once per frame** with the finished image. Measured on a 25,200-frame
four-face clip: 21 callbacks before, 6 after. Anything counting callbacks to infer a frame rate
will read differently.

---

## 2. BprVideo 2.60.0 — 3 exports

Transport only. No models, no detectors, **no licence gate** — opening a camera is not a biometric
operation, so unlike every other Bpr* library there is no `*_Init` taking a `qiCode`.

```c
const char* Bpr_Video_Version(void);                        /* "2.60.0" */

int  Bpr_Video_ProbeSource(const char* cameraUrl, int cameraUrlLen);
     /* 0 opens · -20 URL open failed · -21 device open failed */

void Bpr_FaceVideo_Streaming(const char* camSerialNumber, int camSerialNumberLen,
                             const char* service_path,    size_t service_path_len,
                             const char* cameraUrl,       int cameraUrlLen,
                             int hdWidth, int hdHeight,
                             bool save_flag, bool vis_flag,
                             int saveInterval, int restartStreamingAfterFrames,
                             int* retStrLen, int* errorCode);
```

`Bpr_Video_ProbeSource` exists because "the stream doesn't work" is nearly always one of two
things needing different fixes — **-20** means no FFMPEG in the OpenCV build, **-21** means a
camera index that is absent or already held. Call it at configuration time rather than discovering
it inside a streaming thread.

`Bpr_FaceVideo_Streaming` keeps its name despite containing **no face code** — it never had any.
The .NET sample imports it by that exact name, so renaming it to fix a label would break every
existing host. It will be renamed at BprFace's next major, behind an alias for one release.

`BprVideoRunStream` is deliberately **not** exported. It is driven through `IBprFrameAnalyser`, a
C++ interface a pure-C host cannot construct, so exporting it would be a false promise. C++
consumers link the headers under `src/BprCCTV/BprVideo/`.

---

## 3. BprVision 2.61.0 — 10 exports

Smoke and fight detection. **Not biometrics** — no template, no probe/gallery, nobody identified.
Signatures are character-for-character identical to the ones BprFace 2.24.116 shipped, so a host
moves by changing the library name only.

```c
const char* Bpr_Vision_Version(void);   /* "2.61.0" */

int*  Bpr_SmokeDetect_T12_Init(char* qiCode, size_t qiCodeSize,
          float confThreshold, float nmsThreshold, int* retStrLen, int* errorCode);
void  Bpr_SmokeDetect_T12_DeInit(int* instance, int* retStrLen, int* errorCode);
void  Bpr_SmokeDetect_T12_Stream(int* instance,
          const char* camSerialNumber, int camSerialNumberLen,
          const char* cameraUrl, int cameraUrlLen,
          int hdWidth, int hdHeight, int scaleFactor,
          bool save_flag, bool vis_flag, float confThr,
          BprFrameCallback frameCallback, int* retStrLen, int* errorCode);
void  Bpr_SmokeDetect_T12_Image(int* instance,
          const char* imagePath, size_t imagePathLen,
          bool save_flag, bool vis_flag,
          int* detectionCount, int* retStrLen, int* errorCode);

/* Bpr_FightDetect_T12_{Init,DeInit,Stream,Image} — identical shapes */

void  Bpr_FaceVideo_Streaming(...);   /* same as BprVideo §2 — BprVision links the video layer */
```

`Init` **is** licence-gated (`qiCode` required, fails closed on empty or garbage). The `T12` infix
is a misnomer — T12 is the *face* template id and these produce no template — kept because
renaming would break existing hosts.

Temporal confirmation, not per-frame alarms: smoke confirms on 2 hits in 6 frames, fight on 3 in 8.
Fight is wider and stricter because violence resembles ordinary fast motion for a frame or two.

`scaleFactor` and `confThr` on the `_Stream` calls are **accepted and ignored**. They were dead
before the split and giving them meaning during a refactor would have been a hidden behaviour
change.

---

## 4. The frame callback — all three libraries

```c
typedef void(*BprFrameCallback)(const uint8_t* data, int width, int height, int stride);
```

`stride` is the row pitch **in bytes** and is *not* necessarily `width*3` — a frame that is a view
onto a larger buffer has a larger pitch, and assuming otherwise shears the image on some
resolutions and some cameras. The buffer is engine-owned and valid only for the duration of the
call; **copy before returning**.

---

## 5. Deployment

| library | needs models? | self-contained |
|---|---|---|
| BprFace | **yes** — `bpr.m10001/2/3.onnx` beside the library or in `./models/` | yes |
| BprVideo | no | yes |
| BprVision | **yes** — `bpr.m10005/6.onnx` | yes |

Models resolve **relative to the shared library** via `dladdr` — not the working directory, not
your executable. Search order: `<libdir>/`, `<libdir>/models/`, `<libdir>/.models/`. Move the
library, move the models.

No OpenCV to install, no ONNX Runtime, no `LD_LIBRARY_PATH`. Windows needs no companion deps DLL
for these three (unlike the old BprFace, which imported `libBprFaceDeps.dll`).

Platforms: `SO_Linux` and `DLL_Windows` only. Anything else is a build-time `FATAL_ERROR` rather
than a silent no-op.

---

## 6. Known gaps — stated, not hidden

- **No way to cancel a stream.** `_Stream` blocks until the source ends or ESC is pressed in a
  window a service does not have, and the C ABI has no cancel. A host tearing down mid-stream
  deletes an instance the capture thread is still using.
- **`BprID_Version()` reports `2.24.902`, not `2.24.117`** — the bengine family reports the engine
  version, which is what the proof gate ties them to. The file is still named `2.24.117`.
- **Windows exports 5 extra legacy symbols** the POSIX builds do not
  (`Bpr_FaceQuality_T12_Image`, `Bpr_FaceRecog_T12_*`), because `__declspec(dllexport)` in
  `BprSFaceRecog.cpp` survives `--exclude-all-symbols` while POSIX hides them. Pre-existing; the
  published BprIDEngine 2.24.902 has it too. Do not rely on them.
- **On macOS, BprFace extracts with no models on disk and even with corrupt ones**, so it is not
  reading them from the documented search path. Unexplained. Test model deployment on Linux.
