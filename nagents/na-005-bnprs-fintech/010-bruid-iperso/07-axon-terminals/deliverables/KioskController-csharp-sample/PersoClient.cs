using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace KioskController;

/// One result line from the agent: { status, detail, atr, bureau:{...} }.
public sealed record PersoResult(string Status, string Detail, string? Atr, JsonElement Bureau, string Raw)
{
    public bool Ok => Status == "ok";
}

/// Triggers ONE card on the local kiosk agent's trigger endpoint (127.0.0.1:triggerPort).
/// The agent is a long-running process (see KioskAgentHost); this just sends one request per card.
public static class PersoClient
{
    /// Send one perso trigger and await the single JSON result. The agent tunnels to the bureau, relays
    /// APDUs to the local card, then returns { status, detail, atr, bureau }.
    ///   transport: "tp9000" (feeder) or "mock" (protocol test, no card)
    ///   commit:    true  = LIVE perso (destructive; agent ejects on success, rejects on failure)
    ///              false = read-only preflight (card not changed)
    public static async Task<PersoResult> PersonalizeAsync(
        string dpiB64,
        string hardwareId,
        string transport = "tp9000",
        bool commit = true,
        string inputType = "dpi",   // "dpi" = decode dpiB64 (real perso); "none" = skip dPrep (connectivity test)
        int triggerPort = 9098,
        int timeoutMs = 120_000,
        CancellationToken ct = default)
    {
        // Build the trigger request. inputType "dpi" = the encrypted DPI in dpiB64 (bureau decrypts it).
        string req = JsonSerializer.Serialize(new
        {
            dpiB64,
            hardwareId,
            transport,
            inputType,
            commit,
        });

        // A live perso takes several seconds; bound the whole exchange with one timeout.
        using var op = CancellationTokenSource.CreateLinkedTokenSource(ct);
        op.CancelAfter(timeoutMs);

        using var tcp = new TcpClient();
        // The agent binds its trigger port at startup; briefly retry so the very first trigger after launch
        // doesn't race the agent coming up. (A bare connect-then-close would make the agent log a spurious
        // trigger error, so we only ever connect when we're about to send a real request.)
        for (int attempt = 0; ; attempt++)
        {
            try { await tcp.ConnectAsync("127.0.0.1", triggerPort, op.Token); break; }
            catch (SocketException) when (attempt < 15) { await Task.Delay(200, op.Token); }
        }
        tcp.NoDelay = true;

        await using var ns = tcp.GetStream();
        await ns.WriteAsync(Encoding.UTF8.GetBytes(req + "\n"), op.Token);
        await ns.FlushAsync(op.Token);

        // The agent writes exactly one JSON line, then closes the connection.
        using var reader = new StreamReader(ns, Encoding.UTF8);
        string? line = await reader.ReadLineAsync(op.Token);
        if (string.IsNullOrWhiteSpace(line))
            throw new IOException("kiosk agent closed the connection without a result");

        using var doc = JsonDocument.Parse(line);
        JsonElement root = doc.RootElement;
        string status = root.TryGetProperty("status", out var s) ? s.GetString() ?? "?" : "?";
        string detail = root.TryGetProperty("detail", out var d) ? d.GetString() ?? "" : "";
        string? atr = root.TryGetProperty("atr", out var a) ? a.GetString() : null;
        JsonElement bureau = root.TryGetProperty("bureau", out var b) ? b.Clone() : default;
        return new PersoResult(status, detail, atr, bureau, line);
    }
}
