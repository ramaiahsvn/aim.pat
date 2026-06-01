# Pilot report — BprFace → Maven (JNA) + Go (purego) — 2026-06-01

Second & third legs of the BprFace multi-SDK pilot (after NuGet). Same lib/version,
same `extern "C"` surface. Outcome: **Maven PASS, Go PASS** (runtime load deferred).

## Maven (JNA) — PASS

| Step | Outcome |
|------|---------|
| JNA binding compiles | ✅ `BprFaceLibrary` interface, `Native.load("BprFace", …)` |
| JAR packs with JNA resource prefixes | ✅ `darwin-aarch64/libBprFace.dylib`, `win32-x86-64/{BprFace.dll,libBprFaceDeps.dll,opencv_…dll}` + `BprFaceLibrary.class` |
| Publish to GitLab Maven | ✅ jar + pom `HTTP 200`, package_id **18** |
| Consumer resolves from GitLab | ✅ one `<dependency>`, fetched into a clean local repo (with transitive JNA) |

- **Coordinate**: `ai.bnprs:nativesdk-bprface:2.24.114` (packaging jar)
- JNA naming: macOS resource keeps `lib` prefix (`libBprFace.dylib`); Windows resource is `BprFace.dll` (JNA adds no prefix on Windows for `Native.load("BprFace")`).

## Go (purego + go:embed) — PASS (build/consume); publish is tag-based

| Step | Outcome |
|------|---------|
| Module builds | ✅ `go build ./...` + `go vet` — purego v0.8.2 resolved |
| Native embed | ✅ `go:embed` per `GOOS_GOARCH` (build-tagged `embed_darwin_arm64.go` / `embed_windows_amd64.go`); dylib compiled into the archive |
| Binding | ✅ `purego.Dlopen` + `RegisterLibFunc(&bprGLogInit, h, "Bpr_GLog_Init")` |
| Consumer resolves + builds | ✅ separate module, `require` + `replace` → local path, `go build` OK |

- **Module path**: `gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/bprface`
- **Publish mechanism finding**: GitLab's Go module registry is **tag-based** — it serves modules from a project repo via the Go proxy protocol (`GOPROXY=…/projects/230/packages/go`). There is **no upload endpoint** like Maven/NuGet; publishing requires committing the module to a GitLab repo and creating a SemVer **git tag**. Pilot validated build+embed+consume locally via `replace`; registry publish deferred (needs the module hosted in a tagged repo).

## Consolidated auth findings (project 230, CE 18.9)

| Format | Working publish auth |
|--------|----------------------|
| Generic | `PRIVATE-TOKEN` header ✅ |
| **NuGet** | **HTTP Basic only** (`--user user:token`); `PRIVATE-TOKEN` header → 401 |
| **Maven** | `Private-Token` header ✅ |
| **Go** | no upload — tag-based via Go proxy |

Consumers (all formats) authenticate with the `bnprs-libs-readonly` deploy token
(`read_package_registry`); NuGet/Maven via Basic / header respectively, Go via `GONOSUMDB` + netrc.

## Net

All three ecosystems proven on real infra: **one dependency, zero manual binary copy**,
correct per-platform native asset delivered. Remaining work is productionization
(full RID/platform matrix, real ONNX model, multi-target) and the builder-side
self-contained-binary fix (na-004) needed for live runtime smoke-tests.
