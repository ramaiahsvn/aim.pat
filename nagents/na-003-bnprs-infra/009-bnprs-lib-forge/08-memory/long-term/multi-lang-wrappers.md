---
name: multi-lang-wrappers
description: lib-forge to also publish native libs wrapped as Maven/NuGet/Go all-platform packages (zero-binary consume)
metadata:
  node_type: memory
  type: project
---

**Decision (settled with user):** beyond raw Generic-registry binaries, BNPRS will
ship each portable native lib **wrapped for all three ecosystems × all platforms** so
any consumer repo in the GitLab org adds **one dependency and copies zero binaries**:

| Ecosystem | Interop | OS/arch carried inside the package |
|-----------|---------|------------------------------------|
| Maven (Java) | JNA | JNA resource-prefix dirs in the JAR (`win32-x86-64`, `linux-aarch64`, …) |
| NuGet (.NET) | P/Invoke `[LibraryImport]` | `runtimes/<rid>/native/` (`win-x64`, `win-x86`, `linux-x64`, `linux-arm64`) |
| Go module | purego + `go:embed` | per-`GOOS_GOARCH` embedded binary, extracted at runtime |

Consumer demand is real and **org-wide** (Java/Maven=mGate BPR1002; .NET=License BPR1000,
cPerso TRP1002, SbioidS TRP1001, Misc BPR2002; Go=uTms BPR1004; Android/Kotlin+Flutter
mPOS/Kiosk/AandhiPe). User: don't audit which specific repos consume — many other org
repos will, providing all platforms is the point.

**Architecture — lib-forge still does NOT build.** Wrapping (SWIG/JNA/P-Invoke/purego
codegen + JAR/nupkg/module assembly) is a *build* step → owned by the wrapper-builder agent
**bnprs-lib-multisdk (na-003/010)**, created 2026-06-01 (approved). It drops
publish-ready packages at `build/bnprs-wrappers/<Lib>/v<ver>/{maven,nuget,go}/` +
`native-manifest.json`; lib-forge stays the binary source-of-truth on the Generic registry
and **publishes** those packages to GitLab's **Maven + NuGet + Go** registries on the same
project 230, using the same `bnprs-libs-readonly` deploy token (`read_package_registry`
works for all formats on CE 18.9). Toolchains provisioned on pat-m4p 2026-06-01: Maven
3.9.16, .NET 10.0.108, Go 1.26.1, SWIG. Design docs:
`07-axon-terminals/deliverables/design/{multi-language-packaging,wrapper-builder-agent-spec}.md`.
See [[project-lib-forge]].

**Constraints to honor:** "all platforms" = the portable trio `BprCardQi`,`BprFace`,
`BprLicBase`. `BprICBA`/`BprCardEmv` are Windows-only → partial (win-only) packages,
labeled. `BprFinger`/`BprIris` (proprietary SDK) likely not wrappable. Wrapper version
**== native SemVer** (no drift); embed binary sha256 + source-commit in the package
manifest to preserve provenance/immutability.

**Registry gate — CLEARED 2026-06-01 (API-verified, CE 18.9.0):** GitLab Package Registry
is a single feature with **no per-format toggle** — `packages_enabled=true` on proj 230 +
working Generic means the **Maven / NuGet / Go** endpoints
(`…/projects/230/packages/{maven,nuget,go}`) are already live. Deploy token
**`bnprs-libs-readonly`** (id 1, group 118, `read_package_registry`, not revoked, no expiry)
grants pull across **all** formats — no new token/enable needed. (2nd read token
`bnprs-libs-ro-charan` id 3 also exists.) Proj 230 private; anonymous pull off (401), so
consumers auth with the deploy token.

**Why:** one-dependency / zero-binary consumption across the org's polyglot stack.
**How to apply:** never add the wrapper build to lib-forge; consume the wrapper-builder's
output like `build/bnprs-libs/`. Registry is publish-ready — next is the BprCardQi pilot.
