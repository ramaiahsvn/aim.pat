# BprIDEngine 2.24.901 — Linux deployment (verified end-to-end)

**For:** the team deploying multimodality BprIDEngine on Linux behind an API
**Verified:** 2026-08-01, against the **published registry artifacts**, in a clean
`ubuntu:22.04` container — not a local build.

---

## TL;DR — the two things that go wrong

1. **`BprIDEngine` is the LEAN build and has NO face extractor.** You almost certainly want
   **`BprIDEngine-face`**. Both load fine and both report version `2.24.901`, so the symptom looks
   like a broken library and is not one.
2. **The models must sit beside the `.so`.** Without them Linux returns `-7 module-error` from
   `BprID_Preload` and `BprID_Extract`.

---

## 1. Which package

| Generic package | Size | Face extractor? | Use it when |
|---|---|---|---|
| `BprIDEngine` | ~450 KB | **NO** | finger / iris / palm / knuckle only |
| `BprIDEngine-face` | ~21 MB + 46 MB models | **YES** (T12) | anything involving face |

Measured registrations, by loading the published artifacts:

```
BprIDEngine        extractors: 0x4B01 0x4C01 0x4D01 0x4E01 0x4F01
                   matchers  : 0x4A01 0x4D01 0x4E01 0x4F01
                               ^^^^^^ face M11 MATCHER only — you can score stored face
                               templates but you cannot create one
BprIDEngine-face   extractors: 0x4A02 0x4B01 0x4C01 0x4D01 0x4E01 0x4F01
                   matchers  : 0x4A01 0x4A02 0x4D01 0x4E01 0x4F01
```

Modality codes: `0x4A` face · `0x4B` finger · `0x4C` finger-contactless · `0x4D` palmprint ·
`0x4E` iris · `0x4F` other-bio (knuckle). TID = `(modality << 8) | variant`, so T12 = `0x4A02`.

---

## 2. Fetch it

```bash
BASE=https://gitlab.bnprs.ai/api/v4/projects/230/packages/generic/BprIDEngine-face/2.24.901
mkdir -p /opt/bpr/models
curl --fail --header "PRIVATE-TOKEN: $TOKEN" -o /opt/bpr/libBprIDEngine.so \
     "$BASE/linux-x64/libBprIDEngine.so"
for m in bpr.m10001.onnx bpr.m10002.onnx bpr.m10003.onnx; do
  curl --fail --header "PRIVATE-TOKEN: $TOKEN" -o /opt/bpr/models/$m "$BASE/models/$m"
done
```

`linux-arm64` is published too. Verify against the `.sha256` sidecars.

---

## 3. Layout — this is load-bearing

```
/opt/bpr/
  libBprIDEngine.so
  models/
    bpr.m10001.onnx     232 KB   YuNet detector
    bpr.m10002.onnx      38 MB   SFace recogniser
    bpr.m10003.onnx     7.2 MB   quality
```

Models are resolved **relative to the shared object**, via `dladdr` — not relative to your
executable, not relative to the working directory. The search order is
`<libdir>/`, `<libdir>/models/`, `<libdir>/.models/`. If you move the `.so`, the models move with
it.

`ldd libBprIDEngine.so` reports nothing missing — the library is self-contained (static OpenCV).
No `apt install` of OpenCV, no ONNX Runtime.

---

## 4. Call sequence

```c
BprID_SetLicense(qiCode, 16);      // MUST be first. Extract/Match/Fuse are gated; 0 == OK
BprID_Preload(0x4A02);             // optional but recommended for an API server — see §5
BprID_Extract(0x4A02, &sample, buf, &len);
BprID_Match(0x4A02, probe, plen, gallery, glen, &score, &raw);
```

`BprIDSample` — **field order matters**, `modality` is first and must match the TID:

```c
typedef struct {
    uint8_t        modality;    /* 0x4A for face — must match the TID */
    const uint8_t* bytes;       /* or NULL and use path */
    uint32_t       bytes_len;
    int32_t        width, height, stride;
    uint16_t       dpi;         /* minutiae extractors only; 0 == unset */
    const char*    path;        /* for algorithms that read from disk */
} BprIDSample;
```

Getting this struct wrong is silent: `path` lands at the wrong offset and every call returns
`-5 invalid-input`. (Cost me a false "the artifact is broken" during this very investigation.)

Sizing: pass `out_template == NULL` to query the required size — returns `BPRID_ERR_BUFFER` with
`*io_size` set. A T12 template is **528 bytes**.

---

## 5. For a REST/API server specifically

Call **`BprID_Preload(0x4A02)` at startup, once, after `BprID_SetLicense`.** Models load lazily on
first use otherwise, so the first request of the process pays ~170 ms that every later one does
not — which in an API is indistinguishable from a slow endpoint. Preload moves that cost to
start-up and, on Linux, **fails loudly with `-7 module-error` if the models are not deployed**.
That makes it a genuine readiness check: wire it into your health/readiness probe rather than
discovering a bad deployment on the first user request.

`BprID_SetLicense` re-validates, so `BprID_HasLicense()` flips to 0 when the licence expires — also
worth exposing on a health endpoint.

Thread-safety: each adapter serialises on its own mutex, so concurrent requests are safe but face
extraction is effectively single-threaded per process. Size your worker model accordingly.

---

## 6. Verified behaviour (ubuntu:22.04, published artifact)

```
SetLicense           : 0
Preload T12          : 0 (ok)
Extract a.jpg        : 0 (ok) 528 bytes
Extract b.jpg        : 0 (ok) 528 bytes
Match a~b (same)     : 0.7619
Match a~c (different): 0.0000
ldd                  : nothing missing
```

Same test with `models/` removed:

```
Preload T12          : -7 (module-error)
Extract              : -7 (module-error)
```

Both are correct. Test pair: LFW `Paul_McNulty_0001/0002`.

---

## 7. If you are on 2.24.900 and Maven cannot resolve it

Reported error:

```
Could not find artifact ai.bnprs:nativesdk-bpridengine-face:jar:2.24.900 (absent)
  in bnprs-libs (https://gitlab.bnprs.ai/api/v4/projects/230/packages/maven)
```

**The artifact is present and resolves.** Verified 2026-08-01 from a throwaway project:
`BUILD SUCCESS`, jar downloaded (59.6 MB), at the correct path
`ai/bnprs/nativesdk-bpridengine-face/2.24.900/`.

The error message identifies the cause. It names the **jar** and says *"could not find"* — whereas
a genuine auth failure names the **pom** and says *"could not transfer … 401 Unauthorized"*
(confirmed by reproducing both). So the POM resolved, meaning **auth is working**, and only the jar
was missed. `(absent)` is Maven's marker for a **cached negative result**: once a release artifact
is recorded as missing it is not retried.

Fix:

```bash
rm -rf ~/.m2/repository/ai/bnprs/nativesdk-bpridengine-face
mvn -U dependency:go-offline
```

If it still fails, check for a `<mirror>` with `<mirrorOf>*</mirrorOf>` in `settings.xml` — a mirror
intercepts the `bnprs-libs` repo while keeping its id in the error message, which produces exactly
this wording. Exclude it with `<mirrorOf>*,!bnprs-libs</mirrorOf>`.

Auth requirements: `<server><id>` must equal the repository `<id>` (`bnprs-libs`), header
`Private-Token`, token scope `read_package_registry`.

**Consider moving to 2.24.901** — same face behaviour, plus `BprID_Preload`. Note 901's one
breaking change is data, not API: knuckle moved `0x4C` → `0x4F` (T33→T61, M32→M61), so **stored
knuckle templates must be re-enrolled**. Face, finger, iris and palm are unaffected.

---

## 8. Known gaps

- **macOS resolves models differently and the reason is not understood.** The macOS build extracts
  correctly with no models on disk, and with deliberately corrupt ones. Linux does not. Do not
  assume a layout that works on a developer Mac will work on the Linux target — test on Linux.
- `BprModelBlob.h` still carries a **pre-2.24.116 copy** of the Windows module lookup
  (`GetModuleHandleA("BprFace.dll")` → falls back to the executable), so on Windows blob resolution
  and individual-file resolution disagree about the search directory. Linux/macOS use `dladdr` in
  both and are consistent. Fix queued for na-004/007.
- Neither 901 package went through `publish-library.sh`, so neither has a publish report or a
  sha-verified re-download. The artifacts have now been verified by hand (this document).
