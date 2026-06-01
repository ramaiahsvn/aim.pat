# Skill — NuGet P/Invoke wrapping

Wrap a native lib as a NuGet package with embedded per-RID binaries and a typed
P/Invoke binding. Proven in the BprFace 2.24.114 pilot.

## When to use
A consumer ecosystem is .NET and the native lib has a clean `extern "C"` surface
(Case A) or a C shim (Case B).

## Binding pattern
- `public static partial class <Lib>` with `[LibraryImport("<Name>")]` methods (net7+ source-gen).
- A static ctor calling `NativeLibrary.SetDllImportResolver` that maps the import name to
  `lib<Name>.{dll,dylib,so}` — needed because .NET on Windows does NOT add the `lib` prefix.
- Map types: `char*`→`byte*`/`nuint`, `int*`/`double*`→pointers (use `unsafe partial`), `long`/`int` direct.

## Package layout
```
lib/<tfm>/Bnprs.NativeSdk.<Lib>.dll
runtimes/<rid>/native/<files>        # win-x64, win-x86, linux-x64, linux-arm64, osx-x64, osx-arm64
contentFiles/any/any/models/<model>  # whole-leaf extras (e.g. BprFace onnx)
```

## csproj essentials
- `<TargetFramework>net8.0` (productionize: `netstandard2.0;net8.0`), `<AllowUnsafeBlocks>true`.
- `<None Include="runtimes/**/*">` with `PackagePath=runtimes/%(RecursiveDir)%(Filename)%(Extension)`.
- `NoWarn=$(NoWarn);NU5100;NU5128` (native-outside-lib + no-deps-for-RID are intentional).
- `PackageId=Bnprs.NativeSdk.<Lib>`, `Version=<native SemVer>`.

## Build & verify
```
dotnet build -c Release       # LibraryImport source-gen must compile clean
dotnet pack  -c Release -o <out>
unzip -Z1 <pkg>.nupkg          # confirm lib/<tfm>/ + runtimes/<rid>/native/
```

## Publish (lib-forge does this) — AUTH TRAP
NuGet endpoint needs **HTTP Basic**, not the PRIVATE-TOKEN header:
```
curl --request PUT --user root:$GITLAB_PAT --form package=@<pkg>.nupkg \
  "https://gitlab.bnprs.ai/api/v4/projects/230/packages/nuget/"   # → 201
```
Consumer: `nuget.config` source with Username + ClearTextPassword = `bnprs-libs-readonly` deploy token.

## Pitfalls
- Windows file is `libBprFace.dll` but P/Invoke "BprFace" probes `BprFace.dll` → use the resolver.
- Co-located deps (e.g. `libBprFaceDeps.dll`, opencv) sit in the same `runtimes/<rid>/native/` dir.
- Runtime load needs a self-contained native binary (the pilot macOS dylib linked system opencv → deferred).
