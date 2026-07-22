using System.Text.Json;
using KioskController;

// KioskController — sample app that (1) launches the kiosk agent and (2) triggers cards.
//
// Run:  dotnet run -- <exePath> [bureauHost] [hardwareId] [dpiFile]
//   exePath     path to perso-kiosk-agent.exe (or -tls.exe)   [required]
//   bureauHost  bureau IP/host   (default 127.0.0.1)
//   hardwareId  this kiosk's id  (default KIOSK-DXB-014)
//   dpiFile     file holding the base64 encrypted DPI (optional; "TEST" placeholder if omitted)
//
// Example (UAT):  dotnet run -- "C:\bnprs\perso-kiosk-agent.exe" 10.0.0.5 KIOSK-DXB-014 dpi.b64

string exePath    = args.Length > 0 ? args[0] : throw new ArgumentException("usage: <exePath> [bureauHost] [hardwareId] [dpiFile]");
string bureauHost = args.Length > 1 ? args[1] : "127.0.0.1";
string hardwareId = args.Length > 2 ? args[2] : "KIOSK-DXB-014";
string? dpiFile   = args.Length > 3 ? args[3] : null;

var options = new KioskAgentOptions
{
    ExePath     = exePath,
    BureauHost  = bureauHost,
    BureauPort  = 9099,
    Token       = "uat-token",
    TriggerPort = 9098,

    // --- PROD mutual TLS: point ExePath at perso-kiosk-agent-tls.exe and set these three ---
    // CertPath = @"C:\bnprs\certs\kiosk-KIOSK-DXB-014.pem",
    // KeyPath  = @"C:\bnprs\certs\kiosk-KIOSK-DXB-014.key",
    // CaPath   = @"C:\bnprs\certs\ca.pem",
};

// 1) Launch + supervise the agent (start ONCE; it stays up and listens for triggers). The first trigger
//    below retries the connect briefly, so we don't need a separate readiness wait.
await using var host = new KioskAgentHost(options);
host.Start();

// The encrypted DPI you received for this card (base64). For a mock/preflight run any string works.
string dpiB64 = dpiFile is not null && File.Exists(dpiFile) ? File.ReadAllText(dpiFile).Trim() : "TEST";

Console.WriteLine("""

    Kiosk controller ready. Commands:
      p  = preflight  (transport=mock,   commit=false)  non-destructive tunnel test
      c  = commit     (transport=tp9000, commit=true)   LIVE perso on the feeder card
      q  = quit
    """);

while (true)
{
    Console.Write("> ");
    string? cmd = Console.ReadLine()?.Trim().ToLowerInvariant();
    if (cmd is "q" or "quit" or null) break;

    try
    {
        PersoResult r = cmd switch
        {
            // preflight: pure tunnel test (inputType "none" -> bureau skips dPrep; no card data needed)
            "p" => await PersoClient.PersonalizeAsync("", hardwareId, transport: "mock", commit: false,
                                                      inputType: "none", triggerPort: options.TriggerPort),
            // commit: real live perso with the encrypted DPI over the feeder
            "c" => await PersoClient.PersonalizeAsync(dpiB64, hardwareId, transport: "tp9000", commit: true,
                                                      inputType: "dpi", triggerPort: options.TriggerPort),
            _   => throw new InvalidOperationException($"unknown command '{cmd}' (use p, c, or q)"),
        };

        Console.WriteLine($"  => {(r.Ok ? "OK" : "FAIL")} : {r.Detail}");
        if (r.Atr is not null) Console.WriteLine($"     ATR    : {r.Atr}");
        if (r.Bureau.ValueKind == JsonValueKind.Object) Console.WriteLine($"     bureau : {r.Bureau}");

        // Your UI branches here: r.Ok => card ready (already ejected good);
        //                        !r.Ok => the agent already rejected the card, show retry.
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  error: {ex.Message}");
    }
}

Console.WriteLine("shutting down agent...");
