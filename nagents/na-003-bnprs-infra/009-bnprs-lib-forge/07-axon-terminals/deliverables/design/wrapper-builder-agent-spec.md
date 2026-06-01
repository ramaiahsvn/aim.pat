# Spec — Wrapper-Builder Agent (proposed)

> Author: bnprs-lib-forge (na-003/009) · Status: **proposal for approval** · Date: 2026-06-01
> Purpose: define the upstream agent that BUILDS the Maven/NuGet/Go wrapper packages
> which lib-forge then publishes. Companion to `multi-language-packaging.md`.
> **Not yet created** — needs approval + `./create-agent.sh` (do not scaffold without sign-off).

---

## 1. Why a separate agent

lib-forge is **publish-only** and must never build (core directive). Wrapping a native lib
for Java/.NET/Go is a genuine **build** activity — codegen (SWIG or hand-written
JNA/P-Invoke/purego bindings), compilation of the managed binding, and package assembly.
That work needs its own agent with its own toolchains. The two are mirror images:

| | wrapper-builder (proposed) | lib-forge (existing) |
|---|---|---|
| Verb | **builds** wrapper packages | **publishes** packages |
| Input | native binary + headers | finished wrapper packages |
| Output | `build/bnprs-wrappers/<Lib>/v<ver>/` | GitLab Maven/NuGet/Go registries |
| Never | publishes to the registry | builds / compiles anything |

## 2. Proposed identity

| Field | Value |
|---|---|
| **Name** | `bnprs-lib-wrapper` |
| **Code** | `010` *(next free in na-003; 001–009 used)* |
| **Group** | `na-003-bnprs-infra` *(cross-cutting packaging/DevOps concern, pairs with lib-forge)* |
| **Role** | Native SDK Multi-Language Wrapper Builder |
| **Domain** | jni/jna, p-invoke, purego, swig, cgo, abi-recovery, c-shim, cross-language-bindings, package-assembly |

> Lives in na-003 (infra), **not** na-004/005, because it wraps libs from any domain and is
> a platform tooling concern. If you'd rather domain agents own their own wrappers, the
> alternative is to fold this capability into na-004/na-005 — but that duplicates the
> toolchain across agents; one shared wrapper-builder is the lower-maintenance choice.

## 3. Mission

**Turn an already-built native lib (`.dll`/`.so`/`.dylib` + headers) into ready-to-publish
Maven, NuGet, and Go packages, each carrying the right per-platform binary and a typed API.
Hand the finished packages to lib-forge for publishing. Build nothing native; publish nothing.**

```
domain builder (na-004/005)  ──▶  native binary + headers (bpr.cpp)
        │
   bnprs-lib-wrapper  ──▶  build/bnprs-wrappers/<Lib>/v<ver>/{maven,nuget,go}/ + native-manifest.json
        │
   bnprs-lib-forge (na-003/009)  ──▶  GitLab Maven/NuGet/Go registries (project 230)
```

### Separation of duties — strict
- **Does NOT compile the native lib** — that is the domain/product agent's job; it consumes
  their output.
- **Does NOT invent versions** — wrapper version == native SemVer, read from source.
- **Does NOT publish** — drops packages in the hand-off tree; lib-forge publishes.

## 4. Input contract

Two cases, by what the vendor/domain agent provides (mirrors the `wrappers/` README):

- **Case A — headers available (`bpr.cpp/.../include/*.h`)** → SWIG can auto-generate
  bindings from the C ABI, *or* use hand-written JNA/P-Invoke/purego wrappers. Preferred.
- **Case B — binary only, no headers** → enumerate exports (`dumpbin`/`nm`/`objdump`),
  recover signatures from docs/testing, declare bindings by hand. If the lib is mangled
  C++ (not a clean C ABI), ship a small `extern "C"` **C shim** (`nsshim.c`) first.

Native binaries are sourced **from lib-forge's Generic registry** (project 230) or the local
`build/bnprs-libs/<Lib>/v<ver>/<platform>/` tree — never rebuilt. Headers from `bpr.cpp`
(`src/AprCommon/BprVersions/bpr_versions.h` is the version source-of-truth).

## 5. Output contract (hand-off to lib-forge)

Per `(lib, version)`, drop a publish-ready tree on pat-m4p:
```
build/bnprs-wrappers/<Lib>/v<ver>/
  maven/  <artifact>.jar  (+ .pom)          # JNA resource-prefix dirs inside the JAR
  nuget/  <package>.<ver>.nupkg             # runtimes/<rid>/native/ inside
  go/     <module>.zip (+ .info, .mod)      # go:embed per GOOS_GOARCH
  native-manifest.json                      # provenance + sha256 per embedded binary
```
`native-manifest.json` records, per binary: source repo+commit, builder agent, build date,
the Generic-registry coordinate it came from, and `sha256` (**must match** the registry's
`.sha256`). lib-forge re-verifies sha256 before publishing.

## 6. Per-ecosystem build responsibilities

| Ecosystem | Binding tech | Builder produces |
|---|---|---|
| Maven | JNA typed interface + `Native.load` | `.jar` with `win32-x86-64/`, `linux-x86-64/`, `darwin-aarch64/` … resource dirs + `.pom` |
| NuGet | P/Invoke `[LibraryImport]` (managed `netstandard2.0` dll) | `.nupkg` with `runtimes/<rid>/native/` |
| Go | purego + `go:embed` (one embed file per `GOOS_GOARCH`) | module zip + `.mod`/`.info` |

Platform/lib scope follows `multi-language-packaging.md` §3: portable trio full; `BprICBA`/
`BprCardEmv` Windows-only; `BprFinger`/`BprIris` not wrapped; `BprQiEmv` never. `BprFace`
packages must embed the **whole leaf** (lib + `libBprFaceDeps` + opencv ffmpeg + `bpr.model.onnx`).

## 7. Toolchain prerequisites (pat-m4p)

| Tool | Needed for | Status on pat-m4p |
|---|---|---|
| JDK + **Maven** | Maven/JNA build | JDK ✅ · **Maven ✗ (install)** |
| **.NET SDK** | NuGet/P-Invoke build | **✗ (install)** |
| Go toolchain | Go module build | present (verify `go version`) |
| **SWIG** | Case-A auto-binding | **✗ (install — optional if hand-writing)** |
| CMake | C shim / Case-B build | ✅ |
| `nm` / `objdump` / `dumpbin` | Case-B export enumeration | `nm`/`objdump` ✅ · `dumpbin` = Windows-side |

Provision Maven, .NET SDK, and (optionally) SWIG before first build. `dumpbin` only exists
on Windows — Case-B Windows inspection runs on a Windows host or via the domain agent.

## 8. Versioning & provenance
- Wrapper version **== native SemVer** (read from `bpr_versions.h`); no independent version line.
- Published tuples immutable; re-release = native PATCH bump upstream → re-wrap → re-publish.
- Provenance preserved end-to-end via `native-manifest.json`; sha256 must equal the
  Generic-registry checksum (lib-forge enforces at publish).

## 9. Proposed folder content (nagent-template 01–08)
- `01-dendrite/` — connectors: lib-forge Generic registry (read), `bpr.cpp` headers, `build/bnprs-libs/`.
- `02-cell-body/` — strategy: Case-A (SWIG/hand) vs Case-B (recover/shim) decision logic.
- `04-axon/workflows/` — `caseA-headers`, `caseB-binary-only`, per-ecosystem `build-maven|nuget|go`, `assemble-handoff`.
- `05-myelin-sheath/` — skills: `jna-binding`, `pinvoke-binding`, `purego-binding`, `swig-gen`, `abi-recovery`, `c-shim`.
- `06-node-of-ranvier/` — gates: sha256 matches registry; all in-scope platforms present; binding loads (smoke test) before hand-off.
- `07-axon-terminals/` — output: `build/bnprs-wrappers/` tree + build reports.
- `08-memory/long-term/` — wrapped-lib index, per-lib binding notes (esp. Case-B recovered signatures).

## 10. Guardrails (key)
- **Never compile the native lib** — only consume domain-built binaries.
- **Never publish** to the registry — that is lib-forge's exclusive action.
- **Never invent or bump versions** — read from source; wrapper == native SemVer.
- Confirm before: scaffolding the agent, installing toolchains, shipping a Case-B hand-written
  binding (signatures unverified → mark provisional until smoke-tested).
- Never wrap a deprecated lib (`BprQiEmv`) or a proprietary-SDK lib (`BprFinger`/`BprIris`).

## 11. Dependencies
| This agent | Depends on | Reason |
|---|---|---|
| bnprs-lib-wrapper | na-003/009 bnprs-lib-forge | source of native binaries (Generic registry); destination publisher of wrapper packages |
| bnprs-lib-wrapper | na-004 / na-005 domain agents | they build the native lib + own version/source commit |
| bnprs-lib-wrapper | na-003/003 bnprs-gitlab | registry/token readiness (indirect, via lib-forge) |

## 12. Decisions needed before scaffolding
1. **Name/code/group** — accept `bnprs-lib-wrapper` / `010` / na-003, or fold into na-004/005?
2. **SWIG vs hand-written** as the default Case-A path (SWIG = less code, less control;
   hand-written = precise, more effort).
3. **Toolchain provisioning** — approve installing Maven + .NET SDK (+ SWIG) on pat-m4p.
4. **First target lib** — recommend `BprCardQi` (portable, already published raw, widest demand).
