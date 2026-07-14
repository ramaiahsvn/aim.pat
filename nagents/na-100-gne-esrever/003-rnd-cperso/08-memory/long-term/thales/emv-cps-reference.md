---
name: EMV CPS Reference — GlobalPlatform CPSdemonstrator Spec 2.0 (STORE DATA / DGI perso)
description: Canonical EMV Card Personalization Specification (CPS) structure the perso engine must follow — the STORE DATA/DGI command flow, DGI encryption convention, key/KCV/PIN ordering rules, and status words. Source GlobalPlatform CPSdemonstrator Spec 2.0 (May 2006) in Resources/. Governs perso-script preparation for cperso + iperso; DGI assembly for dprep.
type: reference
---

> Source: `trp1002.cperso.thales/Resources/CPSdemonstrator Spec 2.0.pdf` (GlobalPlatform, May 2006 —
> "Sample Applet to exercise EMV CPS"). Standards refs: EMV CPS v1.0 (2003), GP Card Spec 2.2, EMV 4.1.
> This is the **reference structure our STORE DATA/DGI perso scripts must follow** (cperso Sequencer,
> iperso emitter, dprep DGI assembly). Applies on top of the MC profile's own DGI/tag set.

## Perso command flow (the sequence the engine emits)
```
SELECT              00 A4 04 00 <AID>              -- select the applet instance
INITIALIZE UPDATE   80 50 00 00 08 <host chal>     -- resp: KEYDATA(10) KEYINFO(2) SEQ(2) CARDCHAL(6) CARDCRYPTO(8)  [SCP02]
EXTERNAL AUTH       84 82 <P1> 00 10 <host crypto ∥ C-MAC>   -- P1: 00=no SM · 01=MAC · 03=MAC+ENC
STORE DATA (×N)     84 E2 <P1> <P2seq> <Lc> <DGI data>       -- ONE DGI per command; P2 = sequence number
  ...
STORE DATA (last)   -- last block flips applet to PERSONALIZED and CLOSES the secure channel
READ DATA           80 B2 <P1 table> <P2>          -- read-back verify (optional)
```
> The **last STORE DATA transitions the applet to PERSONALIZED** — this is exactly what moves our test
> card's M/Chip instance from `6999` (SW_APPLET_SELECT_FAILED, unpersonalized) to selectable. See
> [[test-card-inventory]].
>
> **Two finalization models — support both:** (a) CPS demonstrator = the LAST STORE DATA finalizes; (b) the
> BNPRS reference script `MC_EMV_Perso.spi` finalizes with **`SET STATUS <appletAID> -> 07` (PERSONALIZED)**
> after the STORE DATA sequence. Also note `MC_EMV_Perso.spi` uses EXT AUTH **security level 03** (C-MAC +
> C-DECRYPTION) and re-encrypts the PIN block issuer-TK -> card-key (`TranslatePinBlock`) => **PIN-TK is a
> DP input** for this card. See [[mc-perso-script-blueprint]].

## STORE DATA data field
`DGI(2) ∥ Length(1) ∥ DGI-content`. Each DGI is sent in its own STORE DATA. (This CPS demonstrator does
NOT use the advanced features: 3-byte length DGI, multiple DGI per STORE DATA, spanning DGI — but the MC
M/Chip profile may.)

## DGI encryption convention (KEY RULE for dprep)
A DGI whose high byte has the **MSB set (>= 0x8000)** carries **encrypted** content (under the SCP02
**session DEK** SKUDEK, or the static K-DEK); DGIs `< 0x8000` are **clear**. Example set (CPS demonstrator):

| DGI | Content | Enc? |
|---|---|---|
| 0101 | Issuer data (ISID, CARDEXP) | clear |
| 0102 | Cardholder identity (names, DOB) | clear |
| 0103 | Cardholder address | clear |
| **8101** | Cardholder secret data (SSN, birth city/country) | **ENC (DEK)** |
| **8000** | AKS_CPS — Authentication Key to sign output (16B) | **ENC (DEK)** |
| 9000 | KCV of AKS_CPS (3B) | clear |
| **8010** | PIN block (8B) | **ENC (DEK)** |
| 9010 | PIN related (PIN try count, limit) | clear |
| 9102 | FCI data (6F/84/A5: 50,87,5F2D,9F11,9F12,BF0C,C9,DF10,5F28,C0,9F08) | clear |

## KCV method (confirms our C277BA check)
DGI 9000: `KCV = leftmost 3 bytes of 3DES_encrypt(key, 8×0x00)`. This is exactly the method used to verify
the card's ISD master key (KCV `C277BA`) and is the P3a KCV the engine already implements.

## Ordering constraints (Sequencer must honor)
- DGI **8000 (app key) BEFORE 9000 (its KCV)** — else `9315` "Check Value failed for AKS key".
- DGI **9010 (PIN related) BEFORE 8010 (PIN)**.
- Order groups are independent otherwise (Order#1 / Order#2 in the CPS device instructions ORDER field).

## STORE DATA status words (Sequencer error handling)
`9000` ok · `9315` KCV failed for AKS key · `9580` command out of sequence · `6A88` referenced data not
found (unrecognized DGI) · `6B00` wrong P1/P2.

## Applies to
- **dprep** (task-001.3): assemble DGIs with the >=0x8000 encryption flag + honor key/PIN ordering.
- **cperso** (task-001.2 Sequencer) / **iperso** (task-001.1 emitter): emit the STORE DATA loop per this
  flow; treat the LAST STORE DATA as the personalize+close step; map the status words above.
- Cross-ref: engine architecture [[emv-engine-architecture]] §4.6/4.7; card ground truth [[test-card-inventory]].
