# BprIDEngine 2.24.900 — consuming the packages

Published 2026-07-31 to GitLab project **230** (`BPR1000/bpr1000.bnprs-libs`).
One library, six modalities, one C ABI (`BprID_*`, 21 symbols). Source: `bpr.cpp` @ `ddbb211`.

## Pick a variant — you cannot have both

| | lean | face T12 |
|---|---|---|
| Maven | `ai.bnprs:nativesdk-bpridengine:2.24.900` | `ai.bnprs:nativesdk-bpridengine-face:2.24.900` |
| NuGet | `Bnprs.NativeSdk.BprIDEngine 2.24.900` | `Bnprs.NativeSdk.BprIDEngine.Face 2.24.900` |
| Go | `…/go/bpridengine/v2 v2.24.900` | `…/go/bpridengine-face/v2 v2.24.900` |
| Size | ~497 KB | ~60 MB |
| Face T12 extract / match / quality | **no** | yes |

Both ship a native called `BprIDEngine` exporting the same 21 symbols. Depend on both and two
different natives land in one process; which one wins is undefined. This is not a warning you can
design around — pick one at the dependency level.

Take **lean** unless you enrol faces. Everything except face T12 is dependency-free, and face M11
(cosine over a pat-produced T11 vector) is in the lean build too — so lean still *matches* faces,
it just cannot *create* the template. T12 is what buys enrolment, and it costs OpenCV plus three
ONNX models.

## Feature detection, not assumption

Ask the binary rather than inferring from the package name — the same code then runs against
either variant:

```
BprID_HasExtractor(id)   BprID_HasMatcher(id)   BprID_HasQuality(id)
```

`id` is `(modality << 8) | variant`; face T12 is `0x4A02`. Three failure answers are kept
deliberately distinct, and the difference matters when you are diagnosing a deployment:

| status | meaning | usual cause |
|---|---|---|
| `not-present` | the id is absent from this binary | you shipped the lean variant |
| `not-implemented` | an extractor exists, no quality assessor | correct — only T12 has quality |
| `not-registered` | the id is unknown to the engine | wrong id, or a typo in the encoding |

## Licensing

`BprID_SetLicense(qiCode)` must be called and must succeed before `Extract`, `Match` or
`Quality`. The licence is **caller-supplied** and re-validated on every call, never cached.
`BprID_GetVersion` and the error-string helpers need no licence, so a caller can always identify
the binary and render an error even when unlicensed.

Licence check runs **before** argument validation, so an unlicensed caller gets `no-license`
rather than a hint about which argument was wrong.

## Verified numbers

Identical across all three ecosystems on linux/amd64 — the point being that the binding must not
change the answer:

```
T12 quality  normalized = 0.2580570578575134   raw = 25
T12 template 528 bytes
M12 self-match 0.9999999963022734
T21 quality  not-implemented
```

`Quality.raw` is `Bpr_FaceQuality_T12_Image`'s integer verbatim (0–100). **A caller migrating off
the legacy function keeps its existing threshold unchanged** — that compatibility is deliberate.
`normalized` is the same value as a `[0,1]` double for cross-modality comparison.

Lean, same harness: `T12 quality → not-present`, `T12 extract → not-present`, `M11` self-match 1.0.

## Migrating off the legacy BprFace calls

Three behavioural differences will bite a caller that assumes a drop-in:

1. **`qiCode` is now required.** The old `Bpr_FaceRecog_*` path accepted an empty string. The
   existing .NET caller (`FaceChainCleaner.cs`) passes `string.Empty` and will fail at
   `SetLicense`.
2. **The `.t12.yml` corpus is not readable.** Legacy templates are OpenCV `FileStorage` YAML keyed
   `bpr_face_t12_features`, read from a *path*. BprIDEngine templates are 528-byte binary buffers.
   Re-enrol, or write a converter — the formats are not negotiable in either direction.
3. **`save_flag` is gone.** `Bpr_FaceQuality_T12_Image(save_flag=true)` also extracted the face and
   wrote `<path><score>.t12.yml` beside the image; that side effect is how the current caller
   builds its corpus. `BprID_Quality` only scores. To get the template, call `BprID_Extract` and
   persist the bytes yourself — separating scoring from extraction is the point of the unified ABI.

## Auth

Consume with the read-only deploy token `bnprs-libs-readonly` (`read_package_registry`):
NuGet via HTTP Basic, Maven via a `Private-Token` header in `settings.xml`, Go via `GOPROXY` +
netrc. Publishing auth differs per format and has two traps — see na-003/010
`08-memory/long-term/gitlab-publish-auth.md`.

Go note: the `/v2` module-path suffix is required by Go for any version ≥ v2.0.0, so the import
path ends `/v2` while the package name stays `bpridengine`.
