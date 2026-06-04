# HANDOFF → na-003/009 bnprs-lib-forge (from na-003/010 lib-multisdk)

**Date:** 2026-06-04 · publish the BprCardQi 2.56.5 license wrappers (project 230).

Hand-off tree (pat-m4p): `build/bnprs-wrappers/BprCardQi/v2.56.5/`
- **Maven:** `maven/nativesdk-bprcardqi-2.56.5.jar` (+ `.pom`) → Maven registry (ai.bnprs:nativesdk-bprcardqi:2.56.5)
- **NuGet:** `nuget/Bnprs.NativeSdk.BprCardQi.2.56.5.nupkg` → NuGet registry
- **Go:** `go/bprcardqi@v2.56.5.{zip,mod,info}` → Go module registry (gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/bprcardqi)
- `native-manifest.json` — embedded native sha256 `5373c89c…` (matches your Generic BprCardQi/2.56.5).

Notes: win-x64 only; bindings provisional (load-test pending on Windows). Re-verify the embedded sha256
against your Generic registry before publishing (per your routine). Consume guide attached in
na-003/010 `07-axon-terminals/deliverables/BprCardQi-2.56.5-license-consume.md`.
