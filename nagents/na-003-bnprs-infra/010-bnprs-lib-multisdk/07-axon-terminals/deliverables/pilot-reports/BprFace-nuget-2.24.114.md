# Pilot report — BprFace → NuGet (plumbing) — 2026-06-01

First end-to-end run of na-003/010. Goal: validate the **binding → package → publish →
consume** pipeline on pat-m4p. Outcome: **PASS** (runtime load deferred, by design).

## Result

| Step | Outcome |
|------|---------|
| P/Invoke binding compiles | ✅ `LibraryImport` source-gen against BprFace's `extern "C"` surface (`Bpr_GLog_Init`, `Bpr_FaceRecog_T11_CosineSimilarity`) |
| NuGet packs with correct layout | ✅ `lib/net8.0/…dll` + `runtimes/{osx-arm64,win-x64}/native/…` + `contentFiles/.../models/` |
| Publish to GitLab NuGet | ✅ `201 Created`, package_id **17**, project 230 |
| Consumer restore from GitLab | ✅ one `PackageReference`, restored over Basic auth |
| Consumer build + asset staging | ✅ managed dll **and** `libBprFace.dylib` auto-staged into `bin/.../osx-arm64/` — **zero manual binary copy** |
| Runtime load/call | ⏸️ deferred — see Constraints |

## Package

- **Id**: `Bnprs.NativeSdk.BprFace` **2.24.114** (wrapper version == native SemVer)
- **Source**: bpr.cpp @ `16077f5`, native built by na-004; wrapped by na-003/010
- **Interop**: P/Invoke `[LibraryImport]` + `NativeLibrary.SetDllImportResolver` (maps import `BprFace` → `libBprFace.{dll,dylib,so}`)
- **RIDs shipped (pilot)**: `osx-arm64` (real dylib), `win-x64` (real lib+deps+ffmpeg). `win-x86`/linux omitted for size.
- **Model**: `bpr.model.onnx` is a **placeholder** in the pilot (real file ~159 MB embeds identically).
- Workspace (git-ignored build tree): `bpr.cpp/build/bnprs-wrappers/BprFace/v2.24.114/` — `nuget/src` (project), `nuget/*.nupkg`, `nuget/native-manifest.json`, `consumer-test/`.

## Key learnings

1. **GitLab NuGet endpoint requires HTTP Basic auth** (`--user <username>:<token>`), **not** the
   `PRIVATE-TOKEN` header that the Generic registry accepts. Both `dotnet`/curl with the
   `PRIVATE-TOKEN` header → `401`; Basic auth (`root:$GITLAB_PAT`) → `201`. Consumers configure
   the source with `Username` + `ClearTextPassword` (the deploy token).
2. **`runtimes/<rid>/native/` works as designed** — one `PackageReference` and the correct
   per-OS/arch binary lands next to the consumer app automatically.
3. The whole-leaf bundle (lib + deps + model) maps cleanly onto NuGet package paths.

## Constraints surfaced (builder-side, na-004 — not this agent)

- The macOS `libBprFace.dylib` **dynamically links system Homebrew OpenCV 4.13** at
  `/opt/homebrew/opt/opencv/...` + an unresolved `@rpath/libmy_library.dylib`. It is **not
  self-contained**, so it will not load on a clean consumer Mac. A true runtime smoke-test
  needs na-004 to ship a self-contained build (bundle/relink deps via `@rpath` +
  `install_name_tool`), or testing on Windows where deps are already bundled.

## Next

- Repeat for **Maven (JNA)** and **Go (purego)** to prove the other two endpoints (same package, same auth model).
- Raise the self-contained-macOS/Linux build with na-004 to unblock real runtime verification.
- Productionize: multi-target `netstandard2.0`+`net8.0`, add `win-x86`+linux RIDs, embed the real model.
