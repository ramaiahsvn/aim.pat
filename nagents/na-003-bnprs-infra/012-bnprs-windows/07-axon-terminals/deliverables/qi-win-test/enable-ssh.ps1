# =============================================================================
#  enable-ssh.ps1 - turn on OpenSSH Server and install the aim.pat access key
#  na-003/012 bnprs-windows
#
#  RUN AS ADMINISTRATOR:
#     powershell -ExecutionPolicy Bypass -File .\enable-ssh.ps1
#
#  It is idempotent - safe to re-run. It prints, at the end, exactly the facts
#  needed from the Mac side (username, admin status, IPs, service state).
#
#  Why it detects admin membership itself: sshd's shipped config contains a
#     Match Group administrators
#         AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
#  block. For an account in the Administrators group, a key placed in
#  ~\.ssh\authorized_keys is SILENTLY IGNORED. That single trap is the usual
#  reason "the key doesn't work" and you fall back to a password prompt.
# =============================================================================

$ErrorActionPreference = 'Stop'

$PublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKub+SnGuT7LDF35xGkqsb+EEm9If8aPx0I9r2XfKztE claude-code-qitest-20260811'

Write-Host "== [1] OpenSSH Server ==" -ForegroundColor Cyan
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
if ($cap.State -ne 'Installed') {
    Write-Host "  installing..."
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
} else {
    Write-Host "  already installed"
}
Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
Write-Host ("  sshd: " + (Get-Service sshd).Status)

Write-Host "== [2] firewall ==" -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host "  rule created (TCP 22 inbound)"
} else {
    Write-Host "  rule already present"
}

Write-Host "== [3] install the access key ==" -ForegroundColor Cyan

# Is THIS ACCOUNT a member of Administrators? (group membership, not process elevation)
$me = $env:USERNAME
$inAdmins = $false
try {
    $inAdmins = @(Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop |
                  Where-Object { $_.Name -like "*\$me" }).Count -gt 0
} catch {
    # Fall back to the classic tool if Get-LocalGroupMember is unavailable
    $inAdmins = ((net localgroup administrators) -join "`n") -match [regex]::Escape($me)
}

if ($inAdmins) {
    $keyFile = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
    Write-Host "  '$me' IS in Administrators -> $keyFile"
} else {
    $sshDir  = Join-Path $env:USERPROFILE '.ssh'
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    $keyFile = Join-Path $sshDir 'authorized_keys'
    Write-Host "  '$me' is NOT in Administrators -> $keyFile"
}

if (-not (Test-Path $keyFile)) { New-Item -ItemType File -Path $keyFile | Out-Null }

# Idempotent: only add if absent
$existing = @()
if ((Get-Item $keyFile).Length -gt 0) { $existing = Get-Content $keyFile }
if ($existing -contains $PublicKey) {
    Write-Host "  key already present - not duplicated"
} else {
    Add-Content -Path $keyFile -Value $PublicKey -Encoding ascii
    Write-Host "  key appended"
}

# ACLs matter ONLY for the administrators file: if it inherits anything else,
# sshd refuses it as "bad ownership or modes" and silently asks for a password.
if ($inAdmins) {
    icacls $keyFile /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
    Write-Host "  ACLs restricted to Administrators + SYSTEM"
}

Write-Host ""
Write-Host "== send these four facts back ==" -ForegroundColor Green
Write-Host ("  user        : " + (whoami))
Write-Host ("  inAdmins    : " + $inAdmins)
Write-Host ("  computer    : " + $env:COMPUTERNAME)
Write-Host ("  sshd        : " + (Get-Service sshd).Status)
Write-Host ("  keyFile     : " + $keyFile)
Write-Host ("  IPv4        : " + ((Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.IPAddress -notlike '127.*' } |
                Select-Object -ExpandProperty IPAddress) -join ', '))
Write-Host ""
Write-Host "  Java present? (needed for the actual test)" -ForegroundColor Yellow
$java = Get-Command java.exe -ErrorAction SilentlyContinue
if ($java) {
    Write-Host ("  java        : " + $java.Source)
} else {
    $found = @()
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($root -and (Test-Path $root)) {
            $found += Get-ChildItem -Path $root -Filter java.exe -Recurse -ErrorAction SilentlyContinue |
                      Select-Object -First 3 -ExpandProperty FullName
        }
    }
    if ($found.Count -gt 0) {
        Write-Host "  java not on PATH, but found bundled copies:"
        $found | ForEach-Object { Write-Host ("    " + $_) }
    } else {
        Write-Host "  NO java.exe anywhere - a portable JDK will be needed"
    }
}
