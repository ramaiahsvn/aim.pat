# =============================================================================
#  enable-ssh.ps1 - turn on OpenSSH Server and install the aim.pat access key
#  na-003/012 patwin-laptop
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

# -----------------------------------------------------------------------------
#  ELEVATION GUARD - check first, fail clearly.
#  Without this, the first real call (Get-WindowsCapability -Online) throws a raw
#  COMException "The requested operation requires elevation" 20-odd lines in, which
#  looks like a script bug rather than "you need to run this as Administrator".
#
#  Deliberately does NOT self-elevate: Start-Process -Verb RunAs opens a NEW window,
#  and this script's whole purpose is to print facts you then send back. A window that
#  elevates and closes on exit loses exactly the output we need.
# -----------------------------------------------------------------------------
$elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) {
    Write-Host ""
    Write-Host "  NOT RUNNING AS ADMINISTRATOR - stopping before changing anything." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Installing OpenSSH Server, adding a firewall rule and writing to" -ForegroundColor Yellow
    Write-Host "  %ProgramData%\ssh all require elevation." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Re-launch elevated, keeping the window open so the output survives:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Start-Process powershell -Verb RunAs -ArgumentList '-NoExit'," -ForegroundColor White
    Write-Host "      '-ExecutionPolicy','Bypass','-File','$($MyInvocation.MyCommand.Path)'" -ForegroundColor White
    Write-Host ""
    Write-Host "  or: right-click Start -> Terminal (Admin), then re-run this file." -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Log everything to a file next to the script, so the output can be sent back verbatim
# rather than retyped. Non-fatal if the host does not support transcription.
$LogFile = Join-Path $PSScriptRoot 'enable-ssh.log'
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch { $LogFile = $null }

$PublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKub+SnGuT7LDF35xGkqsb+EEm9If8aPx0I9r2XfKztE claude-code-qitest-20260811'

Write-Host "== [1] OpenSSH Server ==" -ForegroundColor Cyan
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
Write-Host ("  capability state: " + $cap.State)

if ($cap.State -ne 'Installed') {
    Write-Host "  installing..."
    try {
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
    } catch {
        # "pending operations" (0x800F0902-class): Add-WindowsCapability shares the
        # component store with Windows Update, and only one operation may hold it.
        # Diagnose it here rather than dumping a COMException the caller must decode.
        Write-Host ""
        Write-Host "  INSTALL BLOCKED BY THE SERVICING STORE" -ForegroundColor Red
        Write-Host ("  " + $_.Exception.Message.Trim()) -ForegroundColor Red
        Write-Host ""
        Write-Host "  Why: Add-WindowsCapability uses the same component store as Windows" -ForegroundColor Yellow
        Write-Host "  Update. Only one servicing operation can hold it at a time." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  --- what is holding it ---" -ForegroundColor Cyan
        $cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        $wu  = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        $pxl = Test-Path (Join-Path $env:WINDIR 'WinSxS\pending.xml')
        $pfr = $null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                          -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
        Write-Host ("  CBS RebootPending        : " + $cbs)
        Write-Host ("  WindowsUpdate reboot req : " + $wu)
        Write-Host ("  WinSxS\pending.xml       : " + $pxl)
        Write-Host ("  PendingFileRenameOps     : " + $pfr)
        foreach ($svc in 'TrustedInstaller','wuauserv','msiserver') {
            $s = Get-Service $svc -ErrorAction SilentlyContinue
            if ($s) { Write-Host ("  service {0,-16}: {1}" -f $s.Name, $s.Status) }
        }
        Write-Host ""
        Write-Host "  --- what to do ---" -ForegroundColor Cyan
        if ($cap.State -eq 'InstallPending') {
            Write-Host "  The capability is ALREADY STAGED (InstallPending). A restart finalises" -ForegroundColor Green
            Write-Host "  it - no reinstall needed. Reboot, then re-run this script." -ForegroundColor Green
        } elseif ($cbs -or $wu -or $pxl -or $pfr) {
            Write-Host "  A reboot is pending. Restart Windows, then re-run this script." -ForegroundColor Yellow
        } elseif ((Get-Service wuauserv -ErrorAction SilentlyContinue).Status -eq 'Running' -or
                  (Get-Service TrustedInstaller -ErrorAction SilentlyContinue).Status -eq 'Running') {
            Write-Host "  Windows Update is actively holding the store. Wait for it to finish" -ForegroundColor Yellow
            Write-Host "  (a few minutes), then re-run this script. No reboot may be needed." -ForegroundColor Yellow
        } else {
            Write-Host "  No obvious pending flag. Try: DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
            Write-Host "  then re-run. If it still fails, Win32-OpenSSH can be installed from its" -ForegroundColor Yellow
            Write-Host "  GitHub release zip, which bypasses the servicing stack entirely." -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "  NOTHING WAS CHANGED on this machine." -ForegroundColor Green
        try { Stop-Transcript | Out-Null } catch { }
        if ($LogFile) { Write-Host ("  Log: " + $LogFile) -ForegroundColor Green }
        exit 2
    }
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

try { Stop-Transcript | Out-Null } catch { }
if ($LogFile) {
    Write-Host ""
    Write-Host ("  Full output saved to: " + $LogFile) -ForegroundColor Green
    Write-Host "  Send that file back - it has everything needed." -ForegroundColor Green
}
Write-Host ""
