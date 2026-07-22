# Running perso-kiosk-agent.exe from C#/.NET on the kiosk

The agent is a **long-running background process** that exposes a local TCP trigger on
`127.0.0.1:9098`. Your kiosk software does two independent things:

1. **Start it once** (at kiosk boot / service start) and keep it alive.
2. **Trigger one card** per issuance by sending one JSON line to `127.0.0.1:9098`.

The agent tunnels to the Bureau, relays APDUs to the local TP9000/card, and returns one JSON
result. It holds no keys or card data at rest.

---

## 1. Launch + supervise the agent (C#)

```csharp
using System.Diagnostics;

sealed class KioskAgent : IDisposable
{
    private Process? _proc;
    private readonly string _exePath;
    private readonly string[] _args;

    public KioskAgent(string exePath, string[] args) { _exePath = exePath; _args = args; }

    public void Start()
    {
        var psi = new ProcessStartInfo
        {
            FileName = _exePath,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = Path.GetDirectoryName(_exePath)!,  // so TP9000.dll next to the exe is found
        };
        foreach (var a in _args) psi.ArgumentList.Add(a);        // ArgumentList quotes each arg safely

        _proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        _proc.OutputDataReceived += (_, e) => { if (e.Data != null) Log("[agent] " + e.Data); };
        _proc.ErrorDataReceived  += (_, e) => { if (e.Data != null) Log("[agent!] " + e.Data); };
        _proc.Exited += (_, __) => Log($"[agent] exited code={_proc?.ExitCode}");  // restart it if this fires

        _proc.Start();
        _proc.BeginOutputReadLine();
        _proc.BeginErrorReadLine();
        Log($"[agent] started pid={_proc.Id}");
    }

    public void Stop()
    {
        if (_proc is { HasExited: false }) { _proc.Kill(entireProcessTree: true); _proc.WaitForExit(3000); }
    }

    public void Dispose() { Stop(); _proc?.Dispose(); }
    private static void Log(string s) => Console.WriteLine(s);  // route to your kiosk log
}
```

Start it once at boot (plain UAT or TLS):

```csharp
// UAT (plain):
var agent = new KioskAgent(@"C:\bnprs\perso-kiosk-agent.exe", new[] {
    "--bureau-host", "10.0.0.5", "--bureau-port", "9099", "--token", "uat-token" });

// PROD (mutual TLS — the -tls build):
// var agent = new KioskAgent(@"C:\bnprs\perso-kiosk-agent.exe", new[] {
//     "--bureau-host", "bureau.bnprs.ai", "--bureau-port", "9099",
//     "--tls", "--cert", @"C:\bnprs\kiosk.pem", "--key", @"C:\bnprs\kiosk.key", "--ca", @"C:\bnprs\ca.pem" });

agent.Start();   // leave running for the life of the kiosk; supervise/restart on Exited
```

> **TP9000.dll** (64-bit) must be next to the exe (WorkingDirectory above ensures it's found).
> The agent loads it at runtime only when `transport = "tp9000"`.

---

## 2. Trigger one card (C#)

```csharp
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

static async Task<JsonDocument> PersonalizeAsync(string dpiB64, string hardwareId,
    string transport = "tp9000", bool commit = true, int timeoutMs = 120_000)
{
    var req = JsonSerializer.Serialize(new {
        dpiB64,                 // the ENCRYPTED DPI, base64 — the bureau decrypts it (kiosk never sees the DEK)
        hardwareId,             // this kiosk's id (CN of its fleet cert in PROD)
        transport,              // "tp9000" (feeder) or "mock"
        inputType = "dpi",
        commit                  // true = LIVE perso (destructive); false = read-only preflight
    });

    using var tcp = new TcpClient();
    await tcp.ConnectAsync("127.0.0.1", 9098);
    tcp.ReceiveTimeout = timeoutMs;                       // live perso can take many seconds
    using var ns = tcp.GetStream();

    // send exactly one line (newline-delimited JSON)
    var payload = Encoding.UTF8.GetBytes(req + "\n");
    await ns.WriteAsync(payload);
    await ns.FlushAsync();

    // read one line back (the agent sends one result, then closes the connection)
    using var reader = new StreamReader(ns, Encoding.UTF8);
    string? line = await reader.ReadLineAsync();
    if (line is null) throw new IOException("agent closed with no result");
    return JsonDocument.Parse(line);
}
```

Use it per card:

```csharp
using var result = await PersonalizeAsync(dpiB64, hardwareId: "KIOSK-DXB-014",
                                          transport: "tp9000", commit: true);
var root   = result.RootElement;
string st  = root.GetProperty("status").GetString()!;   // "ok" | "fail"
string det = root.TryGetProperty("detail", out var d) ? d.GetString()! : "";

if (st == "ok") {
    // bureau confirmed the card is complete; the agent already ejected it as good
    ShowSuccess("Card ready.");
} else {
    // any failure -> the agent already REJECTED the card locally; show retry
    ShowError($"Perso failed: {det}");
}
```

---

## Result shape

```json
{ "status": "ok", "detail": "VISA PERSO COMPLETE", "atr": "3BFE13...",
  "bureau": { "dgisAccepted": 19, "dgisTotal": 19, "secured": true, ... } }
```
- `status` = `ok` (card ejected good) or `fail` (card rejected). On `fail`, `detail` says why
  (`bureau auth`, `card_open`, `dprep: …`, `link lost: …`, a rejected DGI, etc.).
- The `bureau` object carries the live counts for logging (never PAN/PIN/track).

## Notes
- **One trigger = one card.** Call `PersonalizeAsync` again for the next card; the agent
  handles them one at a time.
- **Bench first** with `transport:"mock", commit:false` (proves the tunnel), then
  `transport:"tp9000", commit:false` (feed + read a real card, non-destructive), then
  `commit:true` (live).
- **As a Windows Service:** wrap step 1 in a `BackgroundService`/`IHostedService` (start in
  `StartAsync`, `Stop()` in `StopAsync`), or register the exe itself with `sc.exe create`.
  Either way, the trigger call in step 2 is unchanged.
- Treat `dpiB64` and results as PCI-sensitive; do not log them.
```
