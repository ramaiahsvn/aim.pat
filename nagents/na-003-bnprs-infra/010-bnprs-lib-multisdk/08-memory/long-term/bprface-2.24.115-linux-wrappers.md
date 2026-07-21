---
name: bprface-2.24.115-linux-wrappers
description: BprFace 2.24.115 Linux wrappers (Maven/JNA, NuGet/PInvoke, Go/purego) — native+model co-extraction, self-contained native (no deps lib)
metadata: { node_type: memory, type: project }
---

**Built + smoke-verified the BprFace 2.24.115 Linux wrappers** (2026-07-21) for all three
ecosystems, platforms **linux-x64 + linux-arm64**. Each LOADED OK returning version 2.24.115 in a
`linux/amd64` container. Hand-off tree: `bpr.cpp/build/bnprs-wrappers/BprFace/v2.24.115/{maven,nuget,go}`.

**Native input changed vs the 2.24.114 pilot:** cpp-face (na-004/001) now ships a **self-contained**
`libBprFace.{so,dylib}` (OpenCV 4.10.0 statically bundled) — so there is **NO separate libBprFaceDeps
/ opencv / ffmpeg** to embed anymore. The leaf per platform = the ONE native + the model
`bpr.model.onnx`. Self-contained natives published to the GitLab Generic registry (project 230,
`generic/BprFace/2.24.115/<platform>/…`, + `models/bpr.model.onnx`).

**KEY LESSON — model co-extraction (new, critical):** `bpr.model.onnx` is a 75 MB **encrypted TLV
blob** bundling the 6 real models (bpr.m10001–m10006); `BprModelBlob::extract` reads it and the
native finds it via **its own library directory** (dladdr). Loaders extract only the native to a temp
dir, so the model would be missing — every wrapper's loader MUST extract the native **and** the model
to the SAME temp dir before load. Implemented per ecosystem (user chose "embed native+model in every
package" for fully-offline/zero-copy):
- **Maven (JNA)** `ai.bnprs:nativesdk-bprface:2.24.115` — `BprFaceNative.get()` extracts
  `<jna-prefix>/libBprFace.so` + `models/bpr.model.onnx` to one temp dir, then `Native.load(absPath)`.
  Resource prefixes: `linux-x86-64`, `linux-aarch64`. ~87 MB jar.
- **NuGet (P/Invoke)** `Bnprs.NativeSdk.BprFace 2.24.115` — **net8.0** (NOT netstandard2.0: uses
  `NativeLibrary.SetDllImportResolver`, a .NET 6+ API). Native+model embedded as `EmbeddedResource`
  (explicit `LogicalName`s), a static ctor extracts both to a temp dir and resolves the DllImport there
  — sidesteps the `runtimes/<rid>/native` + .NET-FW `.targets` deployment problem entirely. ~87 MB nupkg.
- **Go (purego)** `…/go/bprface` — `//go:embed native` (both natives + model), pick by `runtime.GOARCH`,
  extract to temp, `purego.Dlopen` + `RegisterLibFunc`. Publishes via **git tag** (no upload endpoint).
  Requires `github.com/ebitengine/purego`.

**Status: built, LOAD-verified, and PUBLISHED (2026-07-21)** to project 230:
- Maven `ai/bnprs/nativesdk-bprface 2.24.115` — PUT jar+pom, `Private-Token` header → 200.
- NuGet `Bnprs.NativeSdk.BprFace 2.24.115` — `curl --user root:$GITLAB_PAT --form package=@…` → 201 (Basic; PRIVATE-TOKEN header 401s).
- Go `…/go/bprface/v2 v2.24.115` — committed the module into project 230's git repo under `go/bprface/`
  + tag `go/bprface/v2.24.115`; `go get …@v2.24.115` resolves (GOPROXY=direct, git insteadOf auth).
LOAD smoke passed on linux/amd64 for all three (`bpr_face_get_version` → 2.24.115). Full-function
smoke (detect/recog) needs a license `qiCode` (BGL/BprLicBase, na-003/011) — deferred.

**KEY LESSON — Go major-version /vN suffix (corrects the nucleus naming scheme):** the nucleus lists
the Go path as `…/go/<lib-lower>`, but these libs are **2.x**, and Go REQUIRES the module path to end
in **`/v2`** for any version ≥ v2.0.0 (else `go get` fails: "module path must match major version
…/v2"). So the real module path is `…/go/bprface/v2` (go.mod `module …/go/bprface/v2`; consumers import
`…/go/bprface/v2`, package name stays `bprface`; tag `go/bprface/v2.24.115`). Apply `/v2` to EVERY Go
wrapper here (BprCardQi etc. are also 2.x). macOS wrapper not built here (natives exist; add
`darwin-aarch64`/`osx-arm64` the same way). Supersedes the yanked 2.24.114 pilot.
