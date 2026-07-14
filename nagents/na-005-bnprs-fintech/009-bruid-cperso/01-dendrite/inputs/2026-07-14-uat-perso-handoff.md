# INPUT → na-005/009 bruid-cperso  (cc: na-005/010 bruid-iperso)

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-14 · **Priority:** HIGH · **Status:** READY TO BUILD (no blockers)

## Hand-off: UAT MC/Visa full perso — ALL mechanisms validated on the card, build the P5 Sequencer
rnd-cperso (planner) has closed EVERY unknown and validated the full chain live (entry -> applet SCP02 ->
STORE DATA). You (central executor) build the P5 Sequencer = port `MC_EMV_Perso.spi` driven with our keys/data.
Design of record: rnd-cperso `08-memory/long-term/thales/` (`mc-perso-script-blueprint.md`, `emv-cps-reference.md`,
`test-card-inventory.md`) + knowledge mem-009..015. Companion perso source: `BprDataPrep/PersoScripts/` +
`Operas/THALES MDA/` traces.

## The two UAT cards (same ATR 3BFE13; distinguish by ISD RID)
- **MC card:** ISD `A000000004000000`; M/Chip placeholder `A0000000180F0000018330324444` = 6999.
- **Visa card:** ISD `A000000003000000`; payment placeholder `A000000018320A020000000000000000` = 6999.
- Both: same UAT ISD key (KCV `C277BA`, **VISA2** diversification, KVN01 — value provided out-of-band, NOT stored); BIXAPP_K3 present.

## Keys (held / verified — KCVs only, values in Resources/UAT_Keys.txt, PCI)
- **ISD SCP02** — open channel + session S-ENC/S-MAC/S-DEK: KCV `C277BA`, VISA2 div.
- **IMK-AC/SMI/SMC** — derive UDK (Option A): KCV `82E136` (recovered from ZMK KCV `A85DE2`). UDK derivation
  VALIDATED (test PAN -> UDK KCV `655857`). UAT IMK is single-length (K1==K2 -> 3DES==single DES).
- Session **DEK** (encrypt 8xxx DGIs) derived per-session from the ISD DEK during SCP02 open.
- NOT needed for DP: CVK, PVK (iCVV/CVV2/PVV parsed from input per the .spi). PIN arrives in input. MENTA DEK = instant only.

## Perso-entry mechanism — RESOLVED + VALIDATED ON THE CARD (mem-015)
Source: real Thales Operas trace `Operas/THALES MDA/Spi4MLB2.trace.txt`. The 6999 placeholder is NOT the
target — INSTALL a FRESH selectable instance under the STANDARD AID with the CORRECT params:
```
SCP02 open (ISD, C277BA/VISA2) -> DELETE stale (idempotent, 6A88 ok)
-> INSTALL [for install & make selectable]:   (EXACT MC command, VALIDATED)
     80E60C002C 0C A0000000180F000001833032  0B A0000000180F0000018303  07 A0000000041010  01 12  07 C9050111000105  00
     pkg=A0000000180F000001833032 | module=A0000000180F0000018303 | INSTANCE=A0000000041010 | priv=12 | params=C9 05 0111000105
-> SELECT A0000000041010 -> 9000/610D (SELECTABLE)
-> the APPLET's own SCP02: INIT UPDATE -> EXT AUTH (same ISD keys, diversified)  [gp --connect A0000000041010 does this]
-> STORE DATA (C-MAC wrapped) -> SET STATUS A0000000041010 07 (PERSONALIZED)
```
VALIDATED live 2026-07-14: INSTALL->9000, SELECT->9000 (was 6999), applet SCP02 open, STORE DATA DGI A002->9000.
Post-perso the card answers to STANDARD `A0000000041010`. VISA: same approach; grep the SAME traces for the
Visa INSTALL (its own pkg/module + C9 params). Earlier WRONG params were C90301000000 — do NOT use.

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

## Status: NO blockers — every mechanism proven live (2026-07-14)
| Mechanism | Validated on card |
|---|---|
| SCP02 auth (ISD) | ✅ INIT UPDATE -> EXT AUTH -> 9000 |
| INSTALL [make selectable] (C9050111000105) | ✅ 9000; SELECT A0000000041010 -> 9000 (was 6999) |
| Applet's own SCP02 | ✅ gp --connect A0000000041010 (INIT UPDATE/EXT AUTH -> 9000) |
| STORE DATA | ✅ DGI A002 -> 9000 (accepted) |
| UDK derivation (Option A, UAT IMK) | ✅ KCV 655857 |
No unknowns remain. Test instances were DELETEd; both cards restored. The Gemalto vendor query
(rnd-cperso 07-axon-terminals/deliverables/2026-07-14-gemalto-query-perso-entry.md) is SUPERSEDED — do not send.

## Your build = full DGI perso (port MC_EMV_Perso.spi, drive with our keys/data)
Everything the .spi assumes is now proven. Remaining engineering (no research): implement UDK derivation from
IMK 82E136, session-DEK encryption of the 8xxx DGIs, ICC RSA keypair + Issuer/ICC certs (task-004), build all
clear DGIs from the ADDONS profile + card record, drive the applet SCP02 (gp --connect or BprCardEmv), read-back
verify + stop-on-error, SET STATUS 07. CVK/PVK NOT needed (iCVV/CVV2/PVV parsed from input per the .spi);
PIN block arrives in input under transport key -> TranslatePinBlock.

## Resolved (do not re-open)
CVK-A/B, PVK: NOT DP keys (.spi parses ICVV/CVV2/PVV from input). ODA/RSA: fully scripted (KMS). PIN: in input.
Only true external dep left = MENTA DEK for the INSTANT channel (bruid-iperso), out-of-band.
