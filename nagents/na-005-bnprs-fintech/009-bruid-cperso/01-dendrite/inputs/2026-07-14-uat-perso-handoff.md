# INPUT → na-005/009 bruid-cperso  (cc: na-005/010 bruid-iperso)

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-14 · **Priority:** HIGH · **Status:** OPEN

## Hand-off: UAT MC/Visa perso — fully specified, ready to build the P5 Sequencer
rnd-cperso (planner) has closed all the unknowns. You (central executor) build + run the P5 Sequencer to
personalize the two UAT test cards. Design of record: rnd-cperso `08-memory/long-term/thales/`:
`mc-perso-script-blueprint.md`, `emv-cps-reference.md`, `test-card-inventory.md` (+ knowledge mem-009..013).

## The two UAT cards (same ATR 3BFE13; distinguish by ISD RID)
- **MC card:** ISD `A000000004000000`; M/Chip placeholder `A0000000180F0000018330324444` = 6999.
- **Visa card:** ISD `A000000003000000`; payment placeholder `A000000018320A020000000000000000` = 6999.
- Both: same UAT ISD key (KCV `C277BA`, **VISA2** diversification, KVN01 — value provided out-of-band, NOT stored); BIXAPP_K3 present.

## Keys (held / verified — KCVs only, values in Resources/UAT_Keys.txt, PCI)
- **ISD SCP02** — open channel + session S-ENC/S-MAC/S-DEK: KCV `C277BA`, VISA2 div.
- **IMK-AC/SMI/SMC** — derive UDK (Option A): KCV `82E136` (recovered from ZMK KCV `A85DE2`). UDK derivation
  VALIDATED (test PAN -> UDK KCV `655857`). UAT IMK is single-length (K1==K2 -> 3DES==single DES).
- Session **DEK** (encrypt 8xxx DGIs) derived per-session from the ISD DEK during SCP02 open.
- Outstanding: CVK (iCVV/CVV2 — only if computed at DP), PIN-TK (8010 PIN block). MENTA DEK = instant channel only.

## Perso-entry mechanism (RESOLVED from the Gemalto trace — mem-013)
The 6999 placeholder is NOT the perso target. INSTALL a FRESH selectable instance under the STANDARD AID:
```
SCP02 open (ISD) -> DELETE stale PSE/PPSE/payment (idempotent, 6A88 ok)
-> INSTALL [for install & make selectable]  INSTANCE = A0000000041010 (MC) / A0000000031010 (Visa)
     from pkg A00000000410 (MC) / A00000000310 (Visa), params C90301000000
-> SELECT the new instance -> 9000  -> INIT UPDATE/EXT AUTH -> STORE DATA
```
Post-perso the card answers to the STANDARD scheme AID.

## STORE DATA / DGI set (blueprint) — 47 DGIs + 35 PUT KEY
Full sequence in mc-perso-script-blueprint.md. EMV CPS rules (emv-cps-reference.md): DGI >= 0x8000 encrypted
under session DEK (8000/8001 UDK keys, 8201-8205 RSA/ODA, 8010 PIN block); clear records 0201/0301/0401-04,
9102 FCI, A0xx/B0xx MC proprietary, 9010 PIN control; last STORE DATA = PERSONALIZED (clears 6999).

## PORT THIS: the perso script is already on disk — MC_EMV_Perso.spi
`TRP1002_cPerso/trp1002.cperso.mces2/BprDataPrep/PersoScripts/MC_EMV_Perso.spi` is a COMPLETE BNPRS/Operas
M/Chip perso script — port it as the P5 Sequencer. Flow: SELECT ISD -> INIT UPDATE -> EXT AUTH (security
level 03 C-MAC+C-DEC) -> SELECT A0000000041010 -> STORE_DATA 0101/0201/0301/0401/8000/A001/8010/8201 (records
in template 70) -> SET STATUS A0000000041010 07 (PERSONALIZED). Encodes UDK derivation (KMS), ICC RSA keypair
+ Issuer/ICC certs + SSAD, PIN-block re-encrypt (TranslatePinBlock -> PIN-TK IS a DP input). Companion config
SPI4MLB2.INI + MC_KMS_Macros.ini. Finalization: support BOTH SET STATUS 07 (.spi) and last-STORE-DATA (CPS).
Perso is now FULLY specified: profile(data) + MC_EMV_Perso.spi(script) + Gemalto trace(47-DGI oracle) + keys.

## Build steps (P5 Sequencer — you)
1. Reproduce the entry (INSTALL make-selectable under standard AID) — per card scheme.
2. Derive UDKs from the UAT IMK (82E136) + card PAN/PSN; place in 8000/8001; verify KCV.
3. Build all clear DGIs from the MC/Visa ADDONS profile + card record; encrypt 8xxx under session DEK.
4. C-MAC-wrap every command; drive with READ-BACK VERIFY + STOP-ON-ERROR (single UAT card each).
5. Tooling: gp.jar can INSTALL + STORE DATA over SCP02, or the BprCardEmv engine.

## Proof-of-life already done (mem-009/013)
Full SCP02 auth to the card verified live (INIT UPDATE -> EXT AUTH -> 9000) with the UAT key. Do NOT
personalize the Gemalto-AID placeholder; INSTALL the standard-AID instance per above.

## Only gating open item — Gemalto INSTALL params for this applet build
Proof-of-life tested on the real card: SCP02 auth works; INSTALL [make selectable] CREATES the instance under
the standard AID (6A82 -> registered) — but with the trace params (C90301000000) it lands in 6999 (our cards'
Gemalto applet build is not selectable pre-perso). Both MC_EMV_Perso.spi and the trace assume SELECT works.
=> Obtain the CORRECT Gemalto INSTALL parameters for THIS applet build (not in profile/.spi) to clear the 6999.
Then the ported .spi flow runs. (Test instance was DELETEd; card restored.)

## Non-blocking opens (confirm w/ bureau)
iCVV/CVV2 supplied-in-DP vs computed (CVK). PIN-TK confirmed a DP input (.spi re-encrypts the PIN block).
