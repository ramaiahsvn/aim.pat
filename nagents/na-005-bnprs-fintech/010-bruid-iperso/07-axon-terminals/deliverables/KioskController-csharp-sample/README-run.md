# KioskController — sample C# app to drive perso-kiosk-agent

A minimal, buildable .NET 8 console app that (1) **launches + supervises** the kiosk agent and
(2) **triggers cards**. No NuGet packages — just the BCL. Copy these files into your kiosk
software, or run as-is to bench.

## Files
- `Program.cs` — wires it together: launches the agent, then an interactive p/c/q loop.
- `KioskAgentHost.cs` — starts/stops/auto-restarts `perso-kiosk-agent.exe`, forwards its logs.
- `PersoClient.cs` — sends one trigger to `127.0.0.1:9098` and parses the JSON result.
- `KioskController.csproj` — net8.0 console project.

## Build
```
dotnet build -c Release
```

## Run
```
dotnet run -- <exePath> [bureauHost] [hardwareId] [dpiFile]
```
- `exePath`    path to `perso-kiosk-agent.exe` (or `-tls.exe`)  [required]
- `bureauHost` bureau IP/host (default 127.0.0.1)
- `hardwareId` this kiosk's id (default KIOSK-DXB-014)
- `dpiFile`    a file holding the base64 encrypted DPI (used by the `c` command)

Example (UAT):
```
dotnet run -- "C:\bnprs\perso-kiosk-agent.exe" 10.0.0.5 KIOSK-DXB-014 dpi.b64
```

Then type:
- `p` — preflight (mock transport, non-destructive) — proves the tunnel end-to-end
- `c` — commit (tp9000, LIVE perso) — reads `dpiFile` and personalizes a feeder card
- `q` — quit (stops the agent)

## PROD (mutual TLS)
Point `exePath` at `perso-kiosk-agent-tls.exe` and set the three cert paths in `Program.cs`
(`KioskAgentOptions.CertPath/KeyPath/CaPath`) to this kiosk's fleet cert/key + the fleet CA
(see `fleet-certs/FLEET-CERT-SETUP.md`). Nothing else changes.

## What to keep for your own software
The two classes are the reusable parts:
- `KioskAgentHost` — start the agent once at boot (or wrap it in a Windows Service:
  `IHostedService.StartAsync` -> `host.Start()`, `StopAsync` -> `DisposeAsync`).
- `PersoClient.PersonalizeAsync(...)` — call once per card; branch your UI on `result.Ok`.

## Notes
- One trigger = one card. `result.Ok` => card personalized + ejected good; `!Ok` => the agent
  already rejected the card, show retry with `result.Detail`.
- A live `commit` perso takes several seconds — the client's default timeout is 120s.
- Verified end-to-end on 2026-07-22 (launch -> preflight -> OK -> shutdown).
