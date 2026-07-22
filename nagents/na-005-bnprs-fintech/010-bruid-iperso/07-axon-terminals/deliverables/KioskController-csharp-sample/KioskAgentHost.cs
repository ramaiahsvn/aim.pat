using System.Diagnostics;

namespace KioskController;

/// How to launch the agent. For UAT leave the TLS paths null. For PROD set all three (and point ExePath at
/// perso-kiosk-agent-tls.exe).
public sealed class KioskAgentOptions
{
    public required string ExePath { get; init; }
    public string BureauHost { get; init; } = "127.0.0.1";
    public int    BureauPort { get; init; } = 9099;
    public string Token      { get; init; } = "uat-token";
    public int    TriggerPort { get; init; } = 9098;   // the agent's local trigger port (--listen)

    // PROD mutual TLS: set all three to your fleet cert / key / CA.
    public string? CertPath { get; init; }
    public string? KeyPath  { get; init; }
    public string? CaPath   { get; init; }
    public bool UseTls => CertPath is not null && KeyPath is not null && CaPath is not null;

    public IEnumerable<string> BuildArgs()
    {
        yield return "--bureau-host"; yield return BureauHost;
        yield return "--bureau-port"; yield return BureauPort.ToString();
        yield return "--token";       yield return Token;
        yield return "--listen";      yield return TriggerPort.ToString();
        if (UseTls)
        {
            yield return "--tls";
            yield return "--cert"; yield return CertPath!;
            yield return "--key";  yield return KeyPath!;
            yield return "--ca";   yield return CaPath!;
        }
    }
}

/// Launches and supervises perso-kiosk-agent.exe as a long-running child process. Start it once at boot;
/// it stays up and listens on its trigger port. Auto-restarts if it exits unexpectedly.
public sealed class KioskAgentHost : IAsyncDisposable
{
    private readonly KioskAgentOptions _opt;
    private Process? _proc;
    private volatile bool _stopping;

    public KioskAgentHost(KioskAgentOptions opt) => _opt = opt;

    public void Start()
    {
        if (_proc is { HasExited: false }) return;

        var psi = new ProcessStartInfo
        {
            FileName = _opt.ExePath,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            // So the agent finds TP9000.dll sitting next to the exe.
            WorkingDirectory = Path.GetDirectoryName(Path.GetFullPath(_opt.ExePath))!,
        };
        foreach (string arg in _opt.BuildArgs()) psi.ArgumentList.Add(arg);  // ArgumentList quotes each arg

        _proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        _proc.OutputDataReceived += (_, e) => { if (e.Data is not null) Console.WriteLine($"[agent] {e.Data}"); };
        _proc.ErrorDataReceived  += (_, e) => { if (e.Data is not null) Console.Error.WriteLine($"[agent!] {e.Data}"); };
        _proc.Exited += (_, _) =>
        {
            if (_stopping) return;
            Console.Error.WriteLine($"[host] agent exited (code={SafeExitCode()}); restarting in 2s");
            _ = Task.Delay(2000).ContinueWith(_ => { if (!_stopping) Start(); });
        };

        _proc.Start();
        _proc.BeginOutputReadLine();
        _proc.BeginErrorReadLine();
        Console.WriteLine($"[host] agent started pid={_proc.Id} " +
                          $"({(_opt.UseTls ? "TLS" : "plain")}) -> {_opt.BureauHost}:{_opt.BureauPort}");
    }

    private int SafeExitCode() { try { return _proc?.ExitCode ?? -1; } catch { return -1; } }

    public async ValueTask DisposeAsync()
    {
        _stopping = true;
        if (_proc is { HasExited: false })
        {
            try { _proc.Kill(entireProcessTree: true); await _proc.WaitForExitAsync(); } catch { /* best effort */ }
        }
        _proc?.Dispose();
    }
}
