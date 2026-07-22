# Send ONE perso trigger to the local agent (127.0.0.1:9098) and print the result.
#   .\trigger.ps1                                   -> preflight over mock (no card, non-destructive)
#   .\trigger.ps1 -Transport tp9000                 -> preflight over the feeder (reads a real card, non-destructive)
#   .\trigger.ps1 -Transport tp9000 -Commit -DpiFile dpi.b64   -> LIVE perso (destructive)
# On a SUCCESSFUL live perso the bureau returns result.output with print + magstripe details for card production.
param(
  [ValidateSet('mock','tp9000')][string]$Transport = 'mock',
  [switch]$Commit,
  [string]$DpiFile,
  [string]$HardwareId = 'KIOSK-DXB-014',
  [int]$Port = 9098
)
$dpi = ''
if ($DpiFile) { if (Test-Path $DpiFile) { $dpi = (Get-Content -Raw $DpiFile).Trim() } else { Write-Host "DPI file not found: $DpiFile" -Foreground Red; exit 1 } }
$req = @{ dpiB64=$dpi; hardwareId=$HardwareId; transport=$Transport; inputType= if($Commit){'dpi'}else{'none'}; commit=[bool]$Commit } | ConvertTo-Json -Compress
try {
  $c = New-Object System.Net.Sockets.TcpClient; $c.Connect('127.0.0.1',$Port)
  $s = $c.GetStream(); $c.ReceiveTimeout = 130000
  $w = New-Object System.IO.StreamWriter($s); $w.NewLine="`n"; $w.AutoFlush=$true; $w.WriteLine($req)
  $r = New-Object System.IO.StreamReader($s); $line = $r.ReadLine(); $c.Close()
  Write-Host "REQUEST : $req" -Foreground DarkGray
  Write-Host "RESULT  : $line" -Foreground Cyan
  $o = $line | ConvertFrom-Json
  if ($o.status -eq 'ok' -and $o.output) {
    Write-Host ""
    Write-Host "PERSO OK - card production payload (print + magstripe):" -Foreground Green
    Write-Host ("  cardholderName : {0}" -f $o.output.print.cardholderName)
    Write-Host ("  pan (masked)   : {0}" -f $o.output.print.panMasked)
    Write-Host ("  expiry         : {0}" -f $o.output.print.expiry)
    Write-Host ("  track1         : {0}" -f $o.output.magstripe.track1)
    Write-Host ("  track2         : {0}" -f $o.output.magstripe.track2)
    Write-Host "  (feed this output to your printer + magstripe encoder; do not persist it)" -Foreground DarkGray
  } elseif ($o.status -ne 'ok') {
    Write-Host ("FAILED: {0}" -f $o.detail) -Foreground Yellow
  }
} catch { Write-Host "ERROR: $($_.Exception.Message)  (is the agent running?)" -Foreground Red }
