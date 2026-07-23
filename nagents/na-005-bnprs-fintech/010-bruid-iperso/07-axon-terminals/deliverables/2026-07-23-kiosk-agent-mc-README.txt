BNPRS perso-kiosk-agent — MasterCard-capable update (2026-07-23)
================================================================
WHAT'S NEW: the kiosk can now personalize BOTH card schemes — Visa (VSDC) and
MasterCard (M/Chip Advance). The bureau (AWS, already updated) selects the scheme
from a "scheme" field the agent now forwards. Visa is unchanged (default).

WHY REPLACE THE EXE: the previous agent build did not forward "scheme", so the
kiosk could only drive Visa. These rebuilt exes forward it. The bureau side is
already live; drop in these exes + trigger.ps1 to enable MasterCard.

CONTENTS
  perso-kiosk-agent.exe        UAT build   — plain TCP + shared token.        (~3.3 MB)
  perso-kiosk-agent-tls.exe    PROD build  — TLS 1.2+ MUTUAL auth (fleet cert). OpenSSL
                                             statically linked; no DLL to install. (~9.6 MB)
  trigger.ps1                  updated: adds -Scheme visa|mc
  SHA256SUMS.txt               integrity hashes

WHICH EXE: same as before — PROD/AWS bureau over TLS = perso-kiosk-agent-tls.exe
(use your existing fleet cert/key + ca.pem and the same bureau host/port/token).
UAT/plain = perso-kiosk-agent.exe. Your fleet certs + connection details are
UNCHANGED (reuse the kiosk-bureau-connection package).

RUN (unchanged from before)
  PROD:  perso-kiosk-agent-tls.exe --bureau-host 98.130.14.127 --bureau-port 9099 ^
           --tls --cert kiosk-<ID>.pem --key kiosk-<ID>.key --ca ca.pem
  Leave it running (background / service). TP9000.dll (64-bit) next to the exe.

TRIGGER A CARD (from PowerShell)
  Visa (default):   .\trigger.ps1 -Transport tp9000 -Commit -DpiFile dpi.b64
  MasterCard:       .\trigger.ps1 -Transport tp9000 -Commit -Scheme mc -DpiFile dpi.b64
  Preflight first (non-destructive):  .\trigger.ps1 -Transport tp9000
  (or raw JSON: add  "scheme":"mc"  to the trigger object sent to 127.0.0.1:9098)

MASTERCARD BENCH ORDER (first MC card — this path is newly wired, confirm live)
  1. Load a MasterCard (M/Chip) card in the feeder (its card manager must be OP_READY
     so INSTALL can create the instance — same rule as the Visa proof).
  2. .\trigger.ps1 -Transport tp9000 -Scheme mc            (preflight: ISD auth only)
  3. .\trigger.ps1 -Transport tp9000 -Scheme mc -Commit    (full MC perso)
  Expect all DGIs -> 9000, applet personalized, card production output returned.
  NOTE: MasterCard via the kiosk is newly wired (logic lifted verbatim from the
  proven local MC perso); this is its FIRST live kiosk run — verify the result.

PROVENANCE: cross-compiled with mingw-w64 (static) on the build host. TP9000.dll is
runtime-loaded (not linked). Verify with SHA256SUMS.txt.
