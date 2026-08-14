# =============================================================================
#  mces2-tailscale.ps1
#  na-003/012 patwin-laptop  --  one-shot Tailscale bootstrap for MCES2
#
#  PURPOSE
#    Make MCES2 reachable over SSH from pat-m4p regardless of which network
#    either machine is on. Tailscale dials OUT only -- no router change, no
#    port forward, nothing exposed to the internet.
#
#  RUN THIS IN AN *ELEVATED* POWERSHELL ON MCES2 (via TeamViewer):
#      powershell -ExecutionPolicy Bypass -File .\mces2-tailscale.ps1
#
#  IT WILL PAUSE and print a login URL. Open that URL in a browser and approve.
#  No password, PIN or key is ever typed into this script.
#
#  ASCII-ONLY on purpose: non-ASCII characters in a .ps1 arrive mangled over
#  scp/file-transfer and produce "Unexpected token" parser errors.
# =============================================================================

$ErrorActionPreference = 'Stop'

$LogFile = Join-Path $env:USERPROFILE 'tailscale-bootstrap.log'
$TsExe   = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
$TsName  = 'mces2'

function Say($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding ASCII
}

"=== mces2 tailscale bootstrap $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" |
    Out-File -FilePath $LogFile -Encoding ASCII

Say "machine   : $env:COMPUTERNAME"
Say "user      : $env:USERDOMAIN\$env:USERNAME"

# ---- [1] elevation -----------------------------------------------------------
# Deliberately does NOT self-elevate: a re-launched window closes on exit and
# you would never get to read the login URL.
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Say "FAIL: not elevated. Close this window, open PowerShell as Administrator, re-run."
    exit 1
}
Say "elevated  : yes"

# ---- [2] already installed? --------------------------------------------------
if (Test-Path $TsExe) {
    Say "tailscale : already present, skipping install"
} else {
    # winget is tried first but is NOT trusted here: on MCES2 2026-08-14 it returned
    # "No package found matching input criteria" for tailscale.tailscale -- the winget
    # source index is missing or stale on this box. So a winget failure is non-fatal
    # and we fall through to the vendor MSI, which is the reliable route.
    $wingetOk = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say "trying winget..."
        $out = & winget install --id tailscale.tailscale --silent --exact `
                     --accept-source-agreements --accept-package-agreements 2>&1
        $out | ForEach-Object { Add-Content -Path $LogFile -Value "  $_" -Encoding ASCII }
        Say "winget exit code: $LASTEXITCODE"
        Start-Sleep -Seconds 3
        $wingetOk = Test-Path $TsExe
    } else {
        Say "winget    : not present"
    }

    if (-not $wingetOk) {
        # Official vendor download host. MCES2 is AMD64 (surveyed 2026-08-13), so amd64.
        $url = 'https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi'
        $msi = Join-Path $env:TEMP 'tailscale-setup.msi'
        Say "winget unusable -- downloading MSI from $url"

        # PS 5.1's progress bar makes Invoke-WebRequest crawl on large files.
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing

        $sz = (Get-Item $msi).Length
        Say "downloaded : $msi ($sz bytes)"
        Say "sha256     : $((Get-FileHash $msi -Algorithm SHA256).Hash)"
        if ($sz -lt 1MB) {
            Say "FAIL: MSI is implausibly small -- likely an error page, not an installer."
            exit 1
        }

        Say "installing silently via msiexec..."
        $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -PassThru
        Say "msiexec exit code: $($p.ExitCode)"
    }

    # The MSI can drop the binary a moment after the installer returns.
    $waited = 0
    while (-not (Test-Path $TsExe) -and $waited -lt 60) {
        Start-Sleep -Seconds 2; $waited += 2
    }
    if (-not (Test-Path $TsExe)) {
        Say "FAIL: tailscale.exe not found at $TsExe after ${waited}s. Report the log."
        exit 1
    }
    Say "installed : $TsExe"
}

Say "version   : $(& $TsExe version 2>&1 | Select-Object -First 1)"

# ---- [3] service -------------------------------------------------------------
$svc = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
if ($null -eq $svc) {
    Say "FAIL: Tailscale service not registered. Report the log."
    exit 1
}
if ($svc.Status -ne 'Running') {
    Say "service   : $($svc.Status) -> starting"
    Start-Service Tailscale
    Start-Sleep -Seconds 3
}
Say "service   : $((Get-Service Tailscale).Status)"

# ---- [4] bring the interface up ----------------------------------------------
#   --unattended    stay connected when no user is logged on (perso station)
#   --accept-dns=false   do NOT touch this box's DNS resolver. Conservative:
#                        MCES2 has working name resolution today and a perso
#                        station is the wrong place to discover a DNS change.
#   --hostname      fixed name so the tailnet address is stable and predictable
Say ""
Say ">>> A LOGIN URL WILL APPEAR BELOW. Open it in a browser and approve."
Say ">>> This step waits for you. Nothing is typed in here."
Say ""

& $TsExe up --unattended --accept-dns=false --hostname=$TsName 2>&1 |
    Tee-Object -FilePath $LogFile -Append

if ($LASTEXITCODE -ne 0) {
    Say "FAIL: 'tailscale up' exited $LASTEXITCODE. Report the log."
    exit 1
}

# ---- [5] report the facts the Mac side needs ---------------------------------
Say ""
Say "--- RESULT ---"
$ip4 = (& $TsExe ip -4 2>&1 | Select-Object -First 1).Trim()
Say "tailscale IPv4 : $ip4"

try {
    $st  = & $TsExe status --json 2>&1 | ConvertFrom-Json
    $dns = $st.Self.DNSName.TrimEnd('.')
    Say "tailnet DNS    : $dns"
    Say "backend state  : $($st.BackendState)"
} catch {
    Say "tailnet DNS    : (could not parse status --json -- paste 'tailscale status' output)"
}

Say ""
Say "sshd status    : $((Get-Service sshd -ErrorAction SilentlyContinue).Status)"
Say ""
Say "DONE. Paste this log back:  $LogFile"
