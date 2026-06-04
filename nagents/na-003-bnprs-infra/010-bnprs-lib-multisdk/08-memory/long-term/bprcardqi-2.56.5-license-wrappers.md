---
name: bprcardqi-2.56.5-license-wrappers
description: Built Maven/NuGet/Go wrappers for BprCardQi 2.56.5 BGL license API (win-x64); .NET FW + Go-windows packaging lessons
metadata: { node_type: memory, type: project }
---

**Built the BGL license/activation wrappers for BprCardQi 2.56.5** (2026-06-04), Case A (clean C ABI).
API wrapped: `bpr_cardqi_hwid / _activate / _is_licensed / _activate_from_store / _license_path`.
Hand-off tree: `bpr.cpp/build/bnprs-wrappers/BprCardQi/v2.56.5/{maven,nuget,go}` + native-manifest.json.
- **NuGet** `Bnprs.NativeSdk.BprCardQi 2.56.5` — netstandard2.0 P/Invoke; built via `dotnet pack`.
- **Maven** `ai.bnprs:nativesdk-bprcardqi:2.56.5` — JNA (`Native.load("BprCardQi")` → `win32-x86-64/BprCardQi.dll`); built via `mvn package`.
- **Go** `…/go/bprcardqi@v2.56.5` — purego + go:embed; proxy .zip/.mod/.info produced.
- **win-x64 only** (2.56.5 has only that native build); bindings **provisional** — PE can't load-test on macOS host.

**Reusable lessons (apply to all native wrappers):**
1. **.NET Framework (4.6.1–4.8) does NOT auto-deploy `runtimes/<rid>/native/`** — that's a .NET Core/SDK
   feature. Ship a `build/<PackageId>.targets` that copies the native to the consumer output (works on
   FW + Core). Also: native is win-x64 → consumer must build **x64** (x86/AnyCPU-32 → BadImageFormatException).
   Prefer **PackageReference** over packages.config (packages.config won't import the .targets reliably).
2. **purego.Dlopen / RTLD_* are unix-only** — Windows needs a split loader (`//go:build windows` →
   `golang.org/x/sys/windows.LoadLibrary`; `!windows` → purego.Dlopen). `RegisterLibFunc` is cross-platform.
3. JNA maps `Native.load("BprCardQi")` → `BprCardQi.dll` (no `lib` prefix) under the resource prefix;
   P/Invoke `DllImport("libBprCardQi")` keeps the `lib` prefix. Name the embedded native per ecosystem.

Consume guide: `07-axon-terminals/deliverables/BprCardQi-2.56.5-license-consume.md`. Handed to lib-forge to publish.
