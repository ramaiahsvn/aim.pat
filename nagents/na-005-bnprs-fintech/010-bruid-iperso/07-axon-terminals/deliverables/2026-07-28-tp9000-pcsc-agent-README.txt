BNPRS perso-kiosk-agent — TP9000 MECHANICS + PC/SC CHIP ACCESS (2026-07-28)
===========================================================================
WHAT YOU ASKED FOR: keep personalizing over PC/SC (which works — it produced the
card that just passed at the POS), but let the machine move the card instead of a
person inserting it into a desktop reader. This package adds a transport that does
exactly that: the TP9000 DLL feeds and positions the card, and the APDUs go out
over a Windows PC/SC reader.

*** RUN THE PROBE FIRST — 2 MINUTES, NO CARD SPENT ***
There is one hard precondition, and it is not something software can decide.

  The TP9000's OWN chip module (the GemCore behind the Nuvia DLL) does NOT present
  itself to Windows as a PC/SC reader. We proved this on this machine: with a card
  fed and powered by the DLL, SCardListReaders returned NO_READERS_AVAILABLE at
  every step. That module is also the one whose block-wait clips A004/A002.

  So this transport works ONLY if the machine has a SEPARATE encoder unit in the
  card path that Windows enumerates as a smart-card reader. The probe tells you
  whether it does, on your hardware, in one run. It is READ-ONLY: it feeds a card,
  lists the readers visible at each step, tries to connect, reads the ATR, sends
  one harmless SELECT, and ejects. It never writes to the chip.

  Put a card in the hopper, then double-click run-probe.cmd (or run it from a
  prompt). It saves everything to probe.log — send us that file.

     run-probe.cmd                 (same as: tp9000-pcsc-probe.exe)

  If your encoder needs the card moved somewhere specific first, add moves (they
  run in order, values are Card_Control options from the Nuvia spec):

     run-probe.cmd --move 0x33                 (feeder card entry)
     run-probe.cmd --move 0x31:2:1 --move 0x33 (change feeder location, then entry)
     run-probe.cmd --no-eject                  (leave the card in place to look at it)

  It ends with a VERDICT line:
    - "CAN drive the chip over PC/SC" + a reader name -> use that name below.
    - "NO separate encoder is visible" -> no software will fix this. The options
      are then: keep the manual desktop reader, fit an encoder unit into the card
      path, or wait for Nuvia to fix the IC_Input block-wait.

  Send us the probe output either way — it is the fact we need.

IF THE PROBE PASSES — RUNNING THE AGENT
  perso-kiosk-agent-hybrid.exe is the same agent you already run (same TLS certs,
  same bureau, same trigger interface) with one new transport: tp9000-pcsc.
  It still supports mock, tp9000 and pcsc, so it is a drop-in replacement.

  Start it with start-agent-hybrid.cmd (same bureau, token and certs as your
  current start script; stderr is appended to kiosk-hybrid.log).

  NOTE the start script does NOT set PCSC_APDU_TRACE. With real cardholder data
  that trace would put PAN / track 2 / PIN block in the log. Turn it on only for a
  vendor-log run on a TEST/DUMMY DPI.

  Then trigger a card (Moves/Reader are whatever the probe told you):
     .\trigger.ps1 -Transport tp9000-pcsc -Scheme mc -Commit -DpiFile dpi.b64 ^
        -Reader "<reader name from the probe>" -Moves "0x33" -SettleMs 800

  Preflight first (non-destructive, proves feed + connect + ISD auth):
     .\trigger.ps1 -Transport tp9000-pcsc -Scheme mc -Reader "<name>" -Moves "0x33"

WHAT THE TRANSPORT DOES, STEP BY STEP
  1. TP9000: feed a card from the hopper (only if one is not already inside).
  2. TP9000: run your -Moves in order (Card_Control).
  3. Wait -SettleMs so the encoder sees the card seated.
  4. PC/SC: connect to the reader, negotiate the protocol, power the chip. This is
     the OS CCID stack — it honors the card's WTX and its fast clock, which is why
     A004/A002/9200 complete here and time out at the DLL's contact station.
  5. Relay the bureau's APDUs over that connection.
  6. Disconnect, then TP9000 ejects a good card or diverts a failed one to the
     reject bin. A failed card is NEVER ejected as good.

  The chip is deliberately never powered by the DLL (no IC_PowerOnEx), so the two
  readers cannot fight over the card.

CONTENTS
  perso-kiosk-agent-hybrid.exe   agent with mock + tp9000 + pcsc + tp9000-pcsc (TLS, static)
  tp9000-pcsc-probe.exe          the read-only go/no-go probe described above
  start-agent-hybrid.cmd         starts the agent, stderr -> kiosk-hybrid.log
  run-probe.cmd                  runs the probe, output -> probe.log (send us this)
  trigger.ps1                    adds -Transport tp9000-pcsc, -Moves, -SettleMs
  SHA256SUMS.txt                 integrity hashes

  Keep TP9000.dll next to the exes, and reuse your existing certs\ folder.

PROVENANCE: cross-compiled with mingw-w64 (static) on the build host; TP9000.dll is
runtime-loaded, not linked. Verify with SHA256SUMS.txt.
