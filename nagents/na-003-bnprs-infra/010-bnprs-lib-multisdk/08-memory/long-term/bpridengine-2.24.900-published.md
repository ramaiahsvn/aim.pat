---
name: bpridengine-2.24.900-published
description: BprIDEngine 2.24.900 published to project 230 in two mutually exclusive variants (lean + face T12) across Maven, NuGet and Go
metadata: { node_type: memory, type: project }
---

**PUBLISHED 2026-07-31** — BprIDEngine 2.24.900, the consolidated engine behind the unified
`BprID_*` C ABI (**21 symbols**, six modalities), to GitLab project **230**
(`BPR1000/bpr1000.bnprs-libs`). Six packages, all consumer-verified after publish.

**TWO VARIANTS, MUTUALLY EXCLUSIVE.** Both ship a library named `BprIDEngine` exporting the same
21 symbols; depending on both puts two different natives in one process and which one loads is
undefined. The split exists because face T12 is the only modality that costs anything — it drags
in OpenCV plus ~46 MB of ONNX. Every other modality is dependency-free, so a caller that does not
enrol faces should not pay 120× the size.

| variant | Maven `ai.bnprs:` | NuGet | Go module | size |
|---|---|---|---|---|
| lean | `nativesdk-bpridengine` | `Bnprs.NativeSdk.BprIDEngine` | `…/go/bpridengine/v2` | ~497 KB |
| t12  | `nativesdk-bpridengine-face` | `Bnprs.NativeSdk.BprIDEngine.Face` | `…/go/bpridengine-face/v2` | ~60 MB |

Go tags: `go/bpridengine/v2.24.900`, `go/bpridengine-face/v2.24.900` (commit e30b2c3 on `master`).
Staging tree: `bpr.cpp/build/bnprs-wrappers/BprIDEngine/v2.24.900{,-t12}/{maven,nuget,go}`.

**Also dropped to the release share** (2026-07-31), for C/C++ hosts and anyone deploying without a
package manager: `Z_RELEASE/_Shared_Libraries/BprIDEngine/v2.24.900/` — 84 MB, following the
newest sibling convention (`BprIPersoAgent/v2.59.0`): `RELEASE-NOTES.md`, `SHA256SUMS.txt`,
`include/bprid_abi.h`, `hosts/java/`, and `lean/` + `t12/` each with three platform folders.
The T12 models are stored ONCE at `t12/models/` rather than duplicated per platform — they are
platform-independent, and the notes tell the integrator to copy them beside the native.
Verified by dlopen from that exact layout: `raw=25`, same as every other path. The lean native
with NO models present loads fine and reports T12 `not-present` — proof the T12 adapter is lazy,
which is what stops a missing model from taking down the other five modalities.

**Version scheme — 900 is deliberate.** `BPR_IDENGINE_VER_PATCH 900`; the 6xx–8xx band is left
free for per-modality releases. 2.24.900 is now burnt: GitLab package versions are immutable, so
any fix ships as .901.

**Verified identically through all three ecosystems** (linux/amd64 containers), which is the
point of the exercise — the numbers must not depend on the binding:
`T12 quality normalized=0.2580570578575134 raw=25`, 528-byte templates, `M12` self-match
`0.9999999963022734`, `T21 quality → not-implemented`. `raw` is
`Bpr_FaceQuality_T12_Image`'s integer verbatim, so a caller migrating off the legacy function
keeps its existing threshold. The lean build degrades honestly rather than faking it:
`T12 → not-present`, `M11` self-match 1.0.

**`not-present` vs `not-implemented` vs `not-registered` are three different answers** and the
ABI keeps them apart: the id is absent from this binary / an extractor exists but no quality
assessor / the id is unknown. Collapsing them would leave a caller unable to tell "wrong package"
from "unsupported operation".

**KEY LESSON — Go struct marshalling across the ABI.** Unlike JNA and P/Invoke, purego has no
struct layout engine: `BprIDSample` is hand-laid with explicit padding plus a compile-time size
assertion (`var _ = [1]struct{}{}[unsafe.Sizeof(cSample{})-48]`) so drift on either side breaks
the build. Every call needs `runtime.KeepAlive` on the path and pixel slices — the collector does
not know C holds those addresses, and without it you get a use-after-free that only appears under
load. Both are invisible-at-review defects, so they are asserted, not commented.

Auth per leg: see [[gitlab-publish-auth]] — the NuGet leg needs `PUT` **with** a trailing slash
and HTTP Basic, and the advertised `PackagePublish` URL is wrong for uploads.

Native/ABI source and the T12 adapter live in `bpr.cpp` under `src/BprIDEngine/`; the face work
belongs to na-004/001. Caller-migration analysis for the existing .NET/Java face app (qiCode now
required, `.t12.yml` corpus not readable by BprIDEngine, `save_flag` side effect gone) is in
`07-axon-terminals/deliverables/`.
