@echo off
REM Starts the BNPRS kiosk agent (TLS) and leaves it running. Run this once; keep the window open.
cd /d "%~dp0"
perso-kiosk-agent-tls.exe --bureau-host 98.130.14.127 --bureau-port 9099 --token 92e11fd0fded8e11af922576 --tls --cert certs\kiosk-KIOSK-DXB-014.pem --key certs\kiosk-KIOSK-DXB-014.key --ca certs\ca.pem
pause
