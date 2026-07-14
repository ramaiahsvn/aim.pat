---
name: MC M/Chip Perso Script Blueprint (ground truth from Gemalto trace)
description: The complete Mastercard M/Chip personalization APDU + DGI sequence extracted from the real Gemalto perso trace (GemaltoCard_Traces_PrePersoInstant_McQi.LOG). This is the executable template for the P5 Sequencer (bruid-cperso central / bruid-iperso instant) to personalize the UAT card. NO key values — structure + DGI map only.
type: reference
---

> Extracted 2026-07-14 from `Resources/GemaltoCard_Traces_PrePersoInstant_McQi.LOG` — the actual
> command stream a Gemalto perso tool sent to personalize an MC M/Chip card. This is the DGI layout +
> flow the applet expects. The P5 Sequencer builds this with OUR card data + derived UDKs. NO key values.

## Perso flow (exact order)
```
SELECT ISD (A000000003000000)  -> INIT UPDATE (80 50, host chal) -> GET RESPONSE (28B: kdd||keyinfo 0102||...)
  -> EXTERNAL AUTHENTICATE (84 82, C-MAC)                      # SCP02 open (KVN=01)
DELETE  (80 E4) x3   : 1PAY.SYS.DDF01 (PSE), 2PAY.SYS.DDF01 (PPSE), A0000000041010 (MC applet)
INSTALL (80 E6 0C) x3: [for install & make selectable] MC applet A0000000041010 + PSE + PPSE dirs
SELECT MC applet (A0000000041010) -> INIT UPDATE -> EXTERNAL AUTHENTICATE   # new SCP02 session for the applet
STORE DATA (80 E2) x47  : sequential P2 = 00..2B then a 2nd/3rd round (see DGI list)   # the perso data
PUT KEY   (80 E0) x35   : card keys (interleaved)
```

## STORE DATA — full DGI sequence (P2 order)
Round 1 (applet, P2 00..2B):
`0201 0301 0302 0401 0402 0403 0404 4D38 9102 A002 A012 A013 A014 A015 A022 A023 A024 A025 B002 A005
B005 A007 A017 A027 A008 A00A 9010 8010 8000 8001 A006 A016 8201 8202 8203 8204 8205 B010 B023 A00E
0E01 B011 B016 5000`
Round 2/3 (dir/second app): `0101 9102 9102`

### DGI groups (by meaning)
- **Records / track / app data (clear):** 0201, 0301, 0302, 0401-0404 (0403/0404 ~232/254B = ODA cert data),
  0E01 (208B), 0101 (issuer data), 9102 (FCI — matches EMV CPS).
- **MC/Gemalto proprietary app params (clear):** A002..A027, B002..B023, 4D38, 5000.
- **ENCRYPTED under session DEK (DGI >= 0x8000 — matches CPS rule):**
  - `8000`, `8001` (48B ea) = symmetric card keys (UDK-AC/SMI/SMC / KMC).
  - `8201`-`8205` (96B ea) = RSA/ODA key material (ICC private key + issuer key components).
  - `8010` (8B) = **PIN block** -> OFFLINE reference PIN IS loaded at DP for this card type.
- **PIN control (clear):** 9010 (PIN try count/limit — matches CPS).

## Perso-entry mechanism — RESOLVED from the trace (2026-07-14)
The pre-installed `6999` applet is NOT the perso target. Gemalto INSTALLs a FRESH selectable instance under
the STANDARD scheme AID and personalizes THAT. Trace evidence (McQi):
```
DELETE  A0000000041010                          <- 6A88   (idempotent cleanup; absent = fine)
INSTALL [for install & make selectable]         <- 6101   ✓ instance created
    pkg=A00000000410 module=A0000000041010 INSTANCE=A0000000041010 priv=00 params=C90301000000
SELECT  A0000000041010                          <- 9000   ← now SELECTABLE
INIT UPDATE -> EXT AUTH -> STORE DATA ...                 (applet's own SCP02 + perso)
```
=> This is why our cards show `6999` on SELECT: the pre-delivered instance under the GEMALTO AID
(`A0000000180F0000018330324444` MC / `A000000018320A02...` Visa) is a placeholder. Personalize by
INSTALLing under the STANDARD AID (`A0000000041010` MC / `A0000000031010` Visa) from the loaded payment
package. BONUS: after perso the card answers to the STANDARD scheme AID (install-time AID = A00000000410 10).

## What the P5 Sequencer must build (from this template)
1. **Entry:** open SCP02 (ISD) -> DELETE stale PSE/PPSE/payment (idempotent) -> **INSTALL [for install &
   make selectable]** the payment applet under the STANDARD AID (A0000000041010 MC / A0000000031010 Visa)
   from the loaded package (MC pkg A00000000410 / Visa pkg A00000000310) -> SELECT (now 9000). Deciding
   whether to DELETE the Gemalto-AID placeholder first is an impl detail (trace card had none -> 6A88).
2. Build each clear DGI's content from our MC ADDONS profile + card record (PAN/expiry/track/service code).
3. Build encrypted DGIs: 8000/8001 with our **UDKs derived from the UAT IMK (KCV 82E136)**; 8010 with the
   PIN block; 8201-8205 with ODA/RSA material — each encrypted under OUR live SCP02 **session DEK**.
4. Wrap every command with **SCP02 C-MAC** (security level from EXTERNAL AUTHENTICATE).
5. Drive with **read-back verify + stop-on-error**; the LAST STORE DATA transitions applet PERSONALIZED
   (clears 6999). Tooling: gp.jar can send STORE DATA over the channel, or the BprCardEmv engine.

## Keys available for this
- ISD SCP02 (open channel + session keys): `C277BA`, VISA2, KVN01 (mem-009).
- IMK-AC/SMI/SMC (derive UDK -> DGI 8000/8001): `82E136` (mem-011).
- Session DEK (to encrypt the 8xxx DGIs): derived per-session from the ISD DEK during SCP02 open.
- Outstanding: CVK (only if iCVV/CVV2 computed here — likely in track DGIs), PIN-TK source for the 8010 PIN block.

## Risk / ownership
Live perso = **implementation** (P5 Sequencer) owned by **bruid-cperso (central) / bruid-iperso (instant)** —
NOT rnd-cperso (planner). Single UAT card: use read-back verify + stop-on-error; a wrong DGI set risks a
half-personalized applet. Cross-ref: [[emv-cps-reference]], [[test-card-inventory]], [[emv-engine-architecture]].
