# Visa POS Ground-Truth — offline decline analysis (KEEP until Visa txn succeeds)

Source: `_Pid1736_Tid0_visa.txt` (Sunmi EMVOptBinderV2, aeonpay, KIOSK-DXB-014).
Card: our perso'd Visa, PAN 4177630223489082, AID A0000000031010 (Visa Debit).

## What happened (NOT the MC issue, NOT an app crash)
Card reads PERFECTLY: `读应用数据: 0` (read-app-data OK), real PAN, name MOHMMED A. SALMAN,
valid 5F24=360331, track2 well-formed. The transaction then **declined OFFLINE**: the terminal
did Terminal Action Analysis and requested **AAC** (`GENERATE AC P1=00`) — it NEVER went online.
Card returned CID=00 (AAC).

## Terminal Action Analysis (computed)
- TVR (95) = **2890048000** = {ICC data missing, DDA failed | CVM NOT successful, PIN required-PIN-pad-not-present | upper-consec-offline | exceeds floor limit}
- Card IAC:  Denial 0010000000  Online B8689C9800  Default B8609C8800
- Term TAC:  Denial 0010000000  Online 584000A800  Default 584000A800
- **TVR & (TAC|IAC)-Denial = 0010000000 → DECLINE.** The SOLE trigger bit = TVR byte2 0x10 =
  "PIN entry required, PIN pad not present/working".
- TVR & (TAC|IAC)-Online = 2800048000 (non-zero) → would GO ONLINE, but Denial is checked FIRST.
- The DDA-failed / ICC-missing / floor-limit bits are NOT in the Denial codes → they do NOT cause
  the decline (they route ONLINE). The cert-chain (fullOda) gap is a RED HERRING for this decline.

## Root cause = CVM
Old CVM list (8E) = `0000000000000000 0205 4203 5E03 1F02` led with **enciphered PIN verified
ONLINE (0x02)**. In an OFFLINE transaction there is no online step → terminal can't do online PIN
→ sets TVR "PIN pad not present/working" → matches IAC/TAC-Denial (0010000000) → AAC.
(MC was fine because MC went ONLINE, where online PIN works.)

## Fix (bpr.cpp orchestrator.cpp:291, bureau sha 9d64613d93455391, deployed 2026-07-24)
CVM list → `000000000000000041031F00` = offline plaintext PIN (0x41, cond 03; card PIN=1234,
self-verify VERIFY→9000) then No-CVM fallback (0x1F, cond always). No online PIN → no denial bit.

## CRITICAL follow-on: this terminal FORCES online (offline approval impossible here)
Term `termOfflineFloorLmt = 000000000000` (floor limit = 0) → EVERY txn exceeds floor → the
"exceeds floor limit" TVR bit (in TAC-Online A8) forces ONLINE. So after the CVM fix the Visa
card will request **ARQC (online)**, exactly like MC. Two paths to an approved Visa sale:
1. ONLINE (mirrors MC): needs a Visa auth host to validate the Visa ARQC (provision PAN + Visa
   IMK-AC at host). Card side ready; Visa path already derives UDK with the card PSN (unlike the
   old MC bug). [[mc-pos-groundtruth]]
2. OFFLINE approval: POS team must RAISE the terminal offline floor limit (terminal-side, we can't
   perso it) AND we drop the AIP DDA claim (or ship fullOda=true + load our test CA on the
   terminal) so DDA-failed/ICC-missing don't force online. Then terminal → TC (offline approve).

## Watch on re-test
- Expect the CVM decline to be GONE; card should progress PAST Terminal Action Analysis.
- On floor-limit-0 terminal it will go ONLINE (ARQC) → needs Visa host (else online failure, not a
  card fault — same as MC -20003 / 88 environment).
- If a NEW offline decline appears, recompute TVR & Denial and update this file.
