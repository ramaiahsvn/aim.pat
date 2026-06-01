# Design — Multi-Language Native SDK Packaging (Maven / NuGet / Go)

> Owner: bnprs-lib-forge (na-003/009) · Status: **draft for approval** · Date: 2026-06-01
> Scope: publish each portable native lib wrapped for three ecosystems × all platforms so
> any GitLab-org consumer **adds one dependency and copies zero binaries**.
> Companion to the raw Generic-registry flow already in production (project 230).

---

## 1. Goal

| Today (Generic registry) | This design adds |
|---|---|
| Consumer `curl`s the raw `.dll`/`.so`, places it on the load path, **writes its own FFI** | Consumer adds **one dependency** in `pom.xml` / `.csproj` / `go.mod`, calls a **typed API**, ships nothing |

The raw Generic flow is **unchanged and remains the binary source-of-truth**. The wrapped
packages are a consumption layer *on top of* it.

## 2. Responsibility split (strict)

```
wrapper-builder agent/repo (wrappers/)          ← BUILDS Maven/NuGet/Go packages (codegen + assembly)
        │ pulls native binary from
lib-forge Generic registry  (project 230)       ← binary source-of-truth (unchanged)
        │ lib-forge PUBLISHES the wrapped packages to
GitLab Maven + NuGet + Go registries (proj 230) ← same server, project, deploy token
```

- **lib-forge never builds.** Generating JNA/P-Invoke/purego bindings and assembling the
  JAR / `.nupkg` / Go module is a build step → owned by the **wrapper-builder** (the
  `wrappers/` layout: `native/`, `swig/`, `java/`, `dotnet/`, `go/`). lib-forge collects its
  output and publishes — exactly as it already does for `build/bnprs-libs/`.
- See `08-memory/long-term/multi-lang-wrappers.md` and `project_lib_forge.md`.

## 3. Library × platform × ecosystem matrix

Only the **portable trio** is a full all-platform target. Constrained libs ship partial or
not at all — never silently mislabeled.

| Lib | Generic (raw) | Maven (JNA) | NuGet (P/Invoke) | Go (purego) | Note |
|-----|:---:|:---:|:---:|:---:|------|
| `BprLicBase` | ✅ | ✅ | ✅ | ✅ | portable |
| `BprCardQi`  | ✅ | ✅ | ✅ | ✅ | portable |
| `BprFace`    | ✅ | ✅ | ✅ | ✅ | portable; bundles `libBprFaceDeps` + opencv ffmpeg + `bpr.model.onnx` per leaf |
| `BprICBA`    | ✅ | win-only | win-only | win-only | Windows-only APIs (+Android) → wrappers ship **win RIDs only**, labeled |
| `BprCardEmv` | ✅ | win-only | win-only | win-only | Windows-only → win RIDs only, labeled |
| `BprFinger`  | ✅ | ❌ | ❌ | ❌ | proprietary SDK → **not wrapped** |
| `BprIris`    | ✅ | ❌ | ❌ | ❌ | proprietary SDK → **not wrapped** |
| `BprQiEmv`   | ❌ | ❌ | ❌ | ❌ | **deprecated — never publish** |

> `BprFace` is not a single file — JNA/NuGet/Go packages must carry the **whole platform
> leaf** (lib + deps + ONNX), extracted together, or the lib won't load.

### Platform-label normalization

The Maven/NuGet/Go fat packages target **desktop + server** JVM/.NET/Go. Android consumers
(mPOS/Kiosk/AandhiPe) consume `.so` via `jniLibs`/AAR — a **separate track**, not these
packages.

| Our native label | NuGet RID | JNA resource prefix | Go `GOOS_GOARCH` |
|---|---|---|---|
| `windows-64`   | `win-x64`     | `win32-x86-64`  | `windows_amd64` |
| `windows-32`   | `win-x86`     | `win32-x86`     | `windows_386`   |
| `windows-arm64`| `win-arm64`   | `win32-aarch64` | `windows_arm64` |
| `linux-x64`*   | `linux-x64`   | `linux-x86-64`  | `linux_amd64`   |
| `linux-arm64`  | `linux-arm64` | `linux-aarch64` | `linux_arm64`   |
| `macos` (x64)  | `osx-x64`     | `darwin-x86-64` | `darwin_amd64`  |
| `macos` (arm64)| `osx-arm64`   | `darwin-aarch64`| `darwin_arm64`  |

> *Coverage gap to flag now:* current build output is Windows + Android heavy. Full
> desktop coverage (`linux-x64`, `macos` x64/arm64) requires the **builder** to produce
> those leaves first — lib-forge cannot fill gaps by building. Packages ship with whatever
> platforms exist and declare the covered set in their manifest.

## 4. GitLab registry endpoints (all on project 230)

GitLab CE 18.9 exposes Maven, NuGet, and Go module registries alongside Generic — same
project (`BPR1000/bpr1000.bnprs-libs`, id 230), same group (`BPR1000`, id 118).

| Format | Publish endpoint (base) |
|---|---|
| Maven | `…/api/v4/projects/230/packages/maven` |
| NuGet | `…/api/v4/projects/230/packages/nuget` |
| Go    | `…/api/v4/projects/230/packages/go` (module proxy under the project) |

**Coordinate with bnprs-gitlab (na-003/003)** to confirm each format is enabled on
project 230 before first publish. *(dependency tracked in `agents.md`)*

## 5. Identifier & naming scheme

| Ecosystem | Package id | Version | Example coordinate |
|---|---|---|---|
| Maven | `ai.bnprs:nativesdk-<lib-lower>` | native SemVer | `ai.bnprs:nativesdk-bprcardqi:2.56.3` |
| NuGet | `Bnprs.NativeSdk.<Lib>` | native SemVer | `Bnprs.NativeSdk.BprCardQi` `2.56.3` |
| Go | `gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/<lib-lower>` | `v`+SemVer tag | `…/go/bprcardqi v2.56.3` |

**Rule: wrapper version == underlying native SemVer.** No second version line that can
drift. Re-release follows the same immutability rule — builder bumps native PATCH, re-wraps.

## 6. Per-ecosystem layout + one-dependency consumer recipe

### 6.1 Maven (JNA)

Package layout (inside the JAR):
```
ai/bnprs/nativesdk/bprcardqi/BprCardQi.class   # typed JNA binding
win32-x86-64/libBprCardQi.dll                  # JNA auto-selects by os/arch
linux-x86-64/libBprCardQi.so
darwin-aarch64/libBprCardQi.dylib
META-INF/native-manifest.json                  # sha256 + source-commit per binary
```
Consumer — add the GitLab repo to `settings.xml` once, then one dependency:
```xml
<dependency>
  <groupId>ai.bnprs</groupId>
  <artifactId>nativesdk-bprcardqi</artifactId>
  <version>2.56.3</version>
</dependency>
```

### 6.2 NuGet (P/Invoke `[LibraryImport]`)

Package layout (inside the `.nupkg`):
```
lib/netstandard2.0/Bnprs.NativeSdk.BprCardQi.dll   # managed typed binding
runtimes/win-x64/native/libBprCardQi.dll
runtimes/linux-x64/native/libBprCardQi.so
runtimes/osx-arm64/native/libBprCardQi.dylib
native-manifest.json
```
Consumer — register source once, then one reference:
```xml
<PackageReference Include="Bnprs.NativeSdk.BprCardQi" Version="2.56.3" />
```

### 6.3 Go (purego + `go:embed`)

Module layout:
```
nativesdk/bprcardqi/
  bprcardqi.go            # typed purego binding
  embed_windows_amd64.go  // go:embed libBprCardQi.dll
  embed_linux_arm64.go    // go:embed libBprCardQi.so   (one per GOOS_GOARCH)
  native_manifest.json
```
Consumer — one line (with `GOPROXY` / `GONOSUMDB` pointed at GitLab):
```bash
go get gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/bprcardqi@v2.56.3
```

## 7. Authentication

| Action | Credential | Notes |
|---|---|---|
| **Publish** (lib-forge, on pat-m4p) | `$GITLAB_PAT` (scope `api`/`write_package_registry`) | never inline the value |
| **Consume** (any org repo / CI) | deploy token **`bnprs-libs-readonly`** (group BPR1000, `read_package_registry`) | **works for Maven, NuGet, and Go** — one credential, all formats |

- Maven: token as `<server>` password in `settings.xml`.
- NuGet: token as the source password (`nuget.config`).
- Go: token in `~/.netrc` for `gitlab.bnprs.ai` (or CI `GOFLAGS`/`GOPROXY` with creds).
- `CI_JOB_TOKEN` still only works cross-project if the consumer is on project 230's
  job-token allowlist — **default consumers to the deploy token.**

## 8. Provenance & immutability

Every wrapped package carries a `native-manifest.json` recording, per embedded binary:
- source repo + commit/tag, builder agent, build date
- the Generic-registry coordinate the binary came from (`package/version/<platform>/<file>`)
- `sha256` (must match the Generic-registry `.sha256` — verified at publish)

Published `(package, version)` tuples are **immutable** — never overwrite. Re-release =
native PATCH bump upstream, re-wrap, re-publish. Each publish appends to
`08-memory/long-term/libraries.yaml` and writes a report to
`07-axon-terminals/deliverables/publish-reports/`.

## 9. Wrapper-builder hand-off contract (what lib-forge needs)

The builder drops, per `(lib, version)`, a publish-ready tree on pat-m4p — analogous to
`build/bnprs-libs/`:
```
build/bnprs-wrappers/<Lib>/v<ver>/
  maven/  <artifact>.jar (+ .pom)
  nuget/  <package>.<ver>.nupkg
  go/     <module>.zip (+ .info, .mod)
  native-manifest.json     # provenance + sha256 (matches Generic registry)
```
lib-forge verifies sha256 against the Generic registry, then publishes each format to
project 230. **lib-forge does not generate bindings or compile.**

## 10. Open items (before first publish)

1. **bnprs-gitlab (na-003/003):** confirm Maven/NuGet/Go registries enabled on project 230;
   confirm `bnprs-libs-readonly` reads all three formats.
2. **Builder ownership:** who owns the `wrappers/` repo — a new wrapper-builder agent, or an
   extension of the domain agents (na-004/na-005)? lib-forge stays publish-only either way.
3. **Desktop coverage:** decide whether `linux-x64` + `macos` leaves are in scope now
   (builder must produce them) or Windows-first.
4. **Android track:** confirm Android stays AAR/`jniLibs` (separate) and is out of scope for
   the Maven/NuGet/Go fat packages.
5. **`BprFace` bundle:** confirm the ONNX model + opencv deps ship inside each wrapper and
   the binding extracts the whole leaf, not just the primary lib.
