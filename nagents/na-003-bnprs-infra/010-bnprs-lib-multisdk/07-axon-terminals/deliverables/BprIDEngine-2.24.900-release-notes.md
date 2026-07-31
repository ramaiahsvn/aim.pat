# BprIDEngine 2.24.900

Released 2026-07-31. Source: `bpr.cpp` @ `ddbb211`.

The consolidated biometric engine: **one library, six modalities, one C ABI**. Face, finger,
fingerprint-contactless, finger-knuckle, palmprint and iris all sit behind the same 21 `BprID_*`
functions, so adding a modality never changes the interface a host compiles against.

## What is in this folder

```
include/bprid_abi.h          the ABI — the only header a host needs
hosts/java/                  working Java integration + sample (see its README)
lean/<platform>/             the lean native
t12/<platform>/              the face-T12 native
t12/models/                  the three ONNX models T12 needs
```

Platforms: `linux-x86-64`, `linux-aarch64`, `darwin-arm64`. Windows is not in this drop.

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

## Prefer the packages over these binaries

For Java, .NET and Go, consume the published packages instead — they embed the native and the
models and stage them correctly at load, so the directory rule above is handled for you:

| | lean | t12 |
|---|---|---|
| Maven | `ai.bnprs:nativesdk-bpridengine:2.24.900` | `ai.bnprs:nativesdk-bpridengine-face:2.24.900` |
| NuGet | `Bnprs.NativeSdk.BprIDEngine 2.24.900` | `Bnprs.NativeSdk.BprIDEngine.Face 2.24.900` |
| Go | `…/go/bpridengine/v2 v2.24.900` | `…/go/bpridengine-face/v2 v2.24.900` |

All from GitLab project 230 (`BPR1000/bpr1000.bnprs-libs`); read access via the
`bnprs-libs-readonly` deploy token. The raw binaries here are for C/C++ hosts and for anyone who
needs to deploy without a package manager.

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

- No Windows build in this drop.
- Only T12 has a quality assessor; every other modality returns `NOT_IMPL` from `BprID_Quality`.
- There is no T11 extractor — pat's capture device produces those; the engine only matches them.
- Accuracy has been verified for self-match and format correctness, not against a labelled corpus.
