@echo off
REM Starts the BNPRS kiosk agent (TLS) and leaves it running. Run this once; keep the window open.
REM
REM The bureau token is NOT stored in this file. It used to be hard-coded on the command line below,
REM which put a live UAT credential into git history (see na-005/010 mem-024). Supply it through the
REM environment for the session instead, or type it when prompted:
REM
REM     set BUREAU_TOKEN=<value>
REM
REM The live value is the --token argument of the bpr-iperso-bureau systemd unit on the bureau EC2
REM (i-00eb79ff8e9e1788b); mem-024 records how to read it. Never commit it.

cd /d "%~dp0"

if "%BUREAU_TOKEN%"=="" set /p BUREAU_TOKEN=Bureau token:
if "%BUREAU_TOKEN%"=="" (
  echo ERROR: BUREAU_TOKEN is empty - the bureau will reject the hello and close the connection.
  pause
  exit /b 1
)

perso-kiosk-agent-tls.exe --bureau-host 98.130.14.127 --bureau-port 9099 --token %BUREAU_TOKEN% --tls --cert certs\kiosk-KIOSK-DXB-014.pem --key certs\kiosk-KIOSK-DXB-014.key --ca certs\ca.pem
pause
