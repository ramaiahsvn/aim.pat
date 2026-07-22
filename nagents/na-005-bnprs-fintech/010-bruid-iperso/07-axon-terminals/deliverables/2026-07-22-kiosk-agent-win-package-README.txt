BNPRS perso-kiosk-agent — Windows x86_64 package
=================================================
The kiosk agent is a long-running background relay between the Bureau (remote perso engine +
HSM + keys) and the local card (Pointman TP9000 feeder / PC/SC). It holds NO keys, NO script,
NO data at rest. The kiosk software starts it once and triggers one card at a time over a
local TCP endpoint (127.0.0.1:9098).

CONTENTS
  perso-kiosk-agent.exe        UAT build      — plain TCP + shared token.        (3.1 MB)
  perso-kiosk-agent-tls.exe    PROD build     — TLS 1.2+ MUTUAL auth (fleet cert). OpenSSL is
                                                statically linked; no DLL to install.  (9.6 MB)
  fleet-certs/
    gen-fleet-certs.sh         make the fleet PKI (CA + bureau + per-kiosk certs)
    FLEET-CERT-SETUP.md        how to generate / distribute / run with certs
  SHA256SUMS.txt               integrity hashes for both exes
  README.txt                   this file

WHICH EXE
  - Bench / UAT / no PKI yet   -> perso-kiosk-agent.exe        (plain)
  - Production                  -> perso-kiosk-agent-tls.exe    (mutual TLS; see fleet-certs/)
  Both take the same trigger and behave identically to the kiosk software — only the bureau
  hop differs (plain vs TLS).

PREREQUISITES ON EACH KIOSK
  1. TP9000.dll (64-BIT — matches these x86_64 exes) next to the exe (loaded at runtime for
     --transport tp9000). Not needed for --transport mock.
  2. Network route to the Bureau host:port.
  3. PROD only: this kiosk's fleet cert + key + the fleet CA (see fleet-certs/FLEET-CERT-SETUP.md).
  No other runtime install — both exes are fully static (OS UCRT only; TLS exe also bundles OpenSSL).

RUN
  UAT:   perso-kiosk-agent.exe --bureau-host <IP> --bureau-port 9099 --token <token>
  PROD:  perso-kiosk-agent-tls.exe --bureau-host <IP> --bureau-port 9099 ^
           --tls --cert kiosk-<ID>.pem --key kiosk-<ID>.key --ca ca.pem
  Leave it running (background / Windows service). Startup prints the trigger port + mode.

TRIGGER ONE CARD (from the kiosk software; see the C# host reference)
  echo {"dpiB64":"<b64 encrypted DPI>","hardwareId":"KIOSK-DXB-014","transport":"tp9000","inputType":"dpi","commit":true} | ncat 127.0.0.1 9098
    transport: "tp9000" (feeder) | "mock" (no card, protocol test)
    commit:    true = LIVE perso (destructive; agent ejects good / rejects on failure)
               false/omit = read-only preflight (card not changed)
  One JSON result line comes back: {"status":"ok"|"fail","detail":"...","bureau":{...}}

BENCH ORDER (recommended, non-destructive first)
  1. transport=mock,   commit=false  -> tunnel + relay path
  2. transport=tp9000, commit=false  -> feed + ATR + read a real card
  3. transport=tp9000, commit=true   -> full live perso on a fresh UAT card

NOTES
  - One trigger = one card; call again for the next. The bureau services many kiosks
    concurrently (its --max-workers), each over a short-lived per-card tunnel.
  - Treat dpiB64 and results as PCI-sensitive; do not log them.
  - Build provenance: cross-compiled with mingw-w64 (static). Verify with SHA256SUMS.txt.
