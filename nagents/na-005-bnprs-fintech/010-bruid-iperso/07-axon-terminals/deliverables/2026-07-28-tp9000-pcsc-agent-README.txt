BNPRS perso-kiosk-agent — TP9000 MECHANICS + PC/SC CHIP ACCESS (2026-07-28)
===========================================================================
WHAT YOU ASKED FOR: keep personalizing over PC/SC (which works — it produced the
card that just passed at the POS), but let the machine move the card instead of a
person inserting it into a desktop reader. This package adds a transport that does
exactly that: the TP9000 DLL feeds and positions the card, and the APDUs go out
over a Windows PC/SC reader.

*** RUN THE PROBE FIRST — 2 MINUTES, NO CARD SPENT ***
The precondition is that a Windows PC/SC reader can see the card once the machine
has positioned it. The probe settles that on your hardware. It is READ-ONLY: feeds
a card, lists the readers visible at each step, connects, reads the ATR, sends one
harmless SELECT, and ejects. It never writes to the chip.

  WHAT WE KNOW SO FAR ON THIS MACHINE (probe run 2026-07-28):
  "SYNIC Smart Card Reader 0" IS enumerated, consistently, before and after a card
  is fed. The first probe run could not connect ("Card was removed" = the reader is
  there but its slot reads empty) because it deliberately engaged neither the
  contacts nor the power. The contacts have to be landed for any reader to see the
  chip — hence --contacts-on. What must NEVER happen is IC_PowerOnEx: that is what
  seizes the chip for the DLL and makes the readers vanish (the July 23 finding).

  Put a card in the hopper, then double-click run-probe.cmd (or run it from a
  prompt). It saves everything to probe.log — send us that file.

     run-probe.cmd --contacts-on   <- START HERE on this machine
     run-probe.cmd                 (no contacts: expect "slot empty")

  If your encoder needs the card moved somewhere specific first, add moves (they
  run in order, values are Card_Control options from the Nuvia spec):

     run-probe.cmd --move 0x33                 (feeder card entry)
     run-probe.cmd --move 0x31:2:1 --move 0x33 (change feeder location, then entry)
     run-probe.cmd --no-eject                  (leave the card in place to look at it)

  It ends with a VERDICT line, one of three:
    - "CAN drive the chip over PC/SC" + a reader name -> use that name below.
    - "reader IS present, but its slot reads EMPTY" -> re-run with --contacts-on
      (or, if contacts were already on, that reader is not the module holding this
      card: try positioning moves and a longer --settle).
    - "NO PC/SC reader is visible at all" -> no software will fix it. Options are
      the manual desktop reader, an encoder unit in the card path, or Nuvia's fix.

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
        -Reader "SYNIC" -SettleMs 800

  -ContactsOn defaults to $true (land the contacts, never power the chip via the
  DLL). Pass -ContactsOn $false only if the encoder is a separate unit that holds
  the card itself. -Moves is only needed if the card must be repositioned first.

  Preflight first (non-destructive, proves feed + connect + ISD auth):
     .\trigger.ps1 -Transport tp9000-pcsc -Scheme mc -Reader "SYNIC"

WHAT THE TRANSPORT DOES, STEP BY STEP
  1. TP9000: feed a card from the hopper (only if one is not already inside), and
     land the IC contacts (-ContactsOn, default on) WITHOUT powering the chip.
  2. TP9000: run your -Moves in order (Card_Control), if any.
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
  trigger.ps1                    adds -Transport tp9000-pcsc, -Moves, -SettleMs, -ContactsOn
  SHA256SUMS.txt                 integrity hashes

  Keep TP9000.dll next to the exes, and reuse your existing certs\ folder.

PROVENANCE: cross-compiled with mingw-w64 (static) on the build host; TP9000.dll is
runtime-loaded, not linked. Verify with SHA256SUMS.txt.
