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

**WINDOWS added to the release share 2026-07-31** (`windows-64` + `windows-32`, both variants;
no `windows-arm64` — no aarch64 mingw on this host). Cross-compiled with mingw-w64 + the prebuilt
static OpenCV in `bpr.cpp/.deps/opencv-build/windows-{64,32}`. Needed four build fixes, all
Windows-only (bpr.cpp `2aa3c62`); non-Windows output verified byte-identical after.

**KEY LESSON — PE does not honour hidden visibility, and the toolchain makes it worse.** The
`.dll` exported **363 symbols instead of 21**, including `BprLicense::patGlobalLicGenerator`, i.e.
the licence generator. `bengine_harden()` only sets visibility presets, which ELF/Mach-O respect
and PE ignores; `toolchains/toolchain_windows_64.cmake` additionally forces
`-Wl,--export-all-symbols`. Fixed with a new `bengine_harden_shared()` applying
`-Wl,--exclude-all-symbols -static $<$<CONFIG:Release>:-s>`. **Any new shared target here must
call it** — visibility presets alone are not an export policy on Windows.

Also: mingw declares `_isnan` itself, so `-D_isnan=isnan` rewrote mingw's own declaration and
broke every Masek file (now non-Windows only); `-lversion` is needed for BprUtils; and `-static`
is needed or the DLL imports three mingw runtime DLLs absent from stock Windows.

**Windows export surface differs from ELF, in Windows' favour** — and this exposed two ELF bugs
worth fixing separately: the `.so` leaks `BprID_LibraryNameImpl` (internal) plus ~22 FJFX/STL
symbols that the `.dll` does not, because the *shared* target lacks the hidden-visibility preset
its static inputs have. The Windows T12 DLL additionally exports the five legacy `Bpr_FaceRecog_T12_*`
entry points, because `BPR_FACE_EXPORT` is `dllexport` on Windows and empty elsewhere — an accident
of the macro, but useful for incremental .NET migration. Kept and documented, not removed.

**Windows T12 numerics are UNVERIFIED.** wine (under x86-64 emulation on Apple Silicon) returned
quality `0.0` and self-match `0.0` — impossible for a valid template — while raising an AVX-state
assertion; extraction produced a correct 528-byte record. Linux T12 gives the right `raw=25` under
the same emulation *without* wine, so emulated SIMD is the likely culprit, but that is an argument
not a measurement. `verify-windows/` in the release folder is a one-minute self-test that settles
it on real hardware. Windows lean IS fully verified.

**OPEN BUG — all three wrappers are broken on Windows** (found 2026-07-31 when a consumer built on
a Windows workstation). Two independent faults: no Windows native is embedded in any package, and
each loader selects the filename by asking only "is this macOS?" — so Windows gets
`libBprIDEngine.so`. Java `BprIDEngineNative`, .NET `BprIDEngine.cs` and Go `nativeName()`/
`libExt()` all have it. **Compiling on Windows is fine** (javac/csc need only the managed classes),
so the failure appears as `UnsatisfiedLinkError` on first engine call, and lazily — a test suite
that never touches the engine still passes. Fixing it means embedding the DLLs (they exist, built
2026-07-31) plus a real platform switch, shipped as 2.24.901. **Deliberately NOT built**: the
current consumer (bpr1004.utms.api.bnet.smartpresence) builds on Windows and deploys to Linux,
which needs nothing. Do it when someone must RUN on Windows.

Auth per leg: see [[gitlab-publish-auth]] — the NuGet leg needs `PUT` **with** a trailing slash
and HTTP Basic, and the advertised `PackagePublish` URL is wrong for uploads.

Native/ABI source and the T12 adapter live in `bpr.cpp` under `src/BprIDEngine/`; the face work
belongs to na-004/001. Caller-migration analysis for the existing .NET/Java face app (qiCode now
required, `.t12.yml` corpus not readable by BprIDEngine, `save_flag` side effect gone) is in
`07-axon-terminals/deliverables/`.
