# M/Chip Advance — canonical STORE DATA / DGI map (from live trace)

> Source of truth: the **Operas Spi4MLB2 trace** (`Resources/Spi4MLB2.trace.txt`) — the actual
> Thales Operas personalization of the physical Gemalto M/Chip Advance V2.4 card (SW=9000 throughout).
> Cross-referenced with the Mastercard perso profile `Card Profiles/MC/PFL_..._Addon_PersoTool_1_MCC.xml`
> (ADDONS worksheets: fci / internal / recordcontact / recordcontactless; 140 tags) for tag VALUES.
> Recorded 2026-07-15 while porting the P5 Sequencer in bpr.cpp (na-005/009 bruid-cperso).

## Key reconciliation result

`BprDataPrep/PersoScripts/MC_EMV_Perso.spi` (our own script) is an **idealized generic-CPS** flow: it
writes only DGIs 0101/0201/0301/0401 + 8000/8010/A001/8201 with plain EMV tags in template 70. The
**real M/Chip Advance card requires far more**: ~31 plaintext + ~10 encrypted DGIs, mixing generic record
DGIs with M/Chip Advance proprietary DGIs (A0xx/B0xx/9xxx) carrying proprietary tags (DFxx/Cx/Dx).

Corrections to the first-pass reading:
- The generic record DGIs (0201/0301/0302/0401/0402/0403/0404) **DO** appear in the real perso — they
  coexist with the proprietary DGIs. Our 0201/0301/0401 builders are real, just a subset.
- DGI **0101 is NOT written** in the primary M/Chip Advance session — AID/FCI/label come from the A0xx
  config DGIs, not a standalone 0101. (0101 only shows up with P1=80 in a secondary session variant.)

## APDU framing (validated, already implemented in bpr.cpp `build_store_data_apdus`)

`CLA=80  INS=E2  P1  P2  Lc  DATA` — one DGI per command, DATA = `DGI_ID(2) || DGI_LEN(1) || DGI_data`.
- **P2** = block sequence number, 0x00, 0x01, … (monotonic).
- **P1** = `0x00` plaintext DGI · `0x60` DEK-encrypted DGI value. (`0x80` last-block seen only in a
  secondary session variant; the primary session does not set it.)
- CLA stays the unsecured logical `0x80`; the SCP02 layer promotes it to `0x84` + C-MAC.

## Canonical STORE DATA sequence (primary session, P2 order)

| P2 | DGI  | P1 | data len | notes |
|----|------|----|----------|-------|
| 00 | A002 | 00 | 6F | CRM parameters — big config DGI (DF22/DF21/DF67/DF7x/C1/C6/C8/C9… proprietary tags) |
| 01 | A012 | 00 | 31 | keyed/CRM block (contact) |
| 02 | A022 | 00 | 31 | keyed/CRM block (contactless) |
| 03 | B010 | 00 | 04 | (trace value 00000000) |
| 04 | B023 | 00 | 04 | (trace value 00000000) |
| 05 | B002 | 00 | 23 | |
| 06 | A007 | 00 | 03 | |
| 07 | A017 | 00 | 05 | |
| 08 | A027 | 00 | 05 | |
| 09 | A008 | 00 | 02 | |
| 0A | A009 | 00 | 30 | |
| 0B | A00A | 00 | 06 | |
| 0C | A202 | 00 | 01 | (trace value 01) |
| 0D | A001 | 00 | 4C | |
| 0E | 9101 | 00 | 4C | |
| 0F | A005 | 00 | 0A | |
| 10 | B005 | 00 | 0E | |
| 11 | A00E | 00 | 0D | |
| 12 | B011 | 00 | 20 | |
| 13 | B016 | 00 | 20 | |
| 14 | 0201 | 00 | A9 | **generic record** — Track2/PAN/dates (our builder covers this) |
| 15 | 0301 | 00 | 95 | **generic record** — name/CVM/language |
| 16 | 0302 | 00 | 44 | generic record 2 of SFI 03 |
| 17 | 0401 | 00 | E8 | **generic record** — CDOL/IAC/AIP/AFL |
| 18 | 0402 | 00 | 09 | |
| 19 | 0403 | 00 | E8 | |
| 1A | 0404 | 00 | FE | |
| 1B | AD14 | 00 | (Lc=02, id-only) | control DGI, no data body |
| 1C | 0E01 | 00 | D0 | |
| 1D | 8010 | **60** | 08 | **encrypted** — **PIN** (8-byte block; NOT the ICC key — per trace REM "EMV DGI 8010 - PIN") |
| 1E | 9010 | 00 | 01 | |
| 1F | 8201 | **60** | 60 | **encrypted** — **ICC RSA priv key: Component PQ (qInv)** |
| 20 | 8202 | **60** | 60 | **encrypted** — **ICC RSA priv key: Component DQ** |
| 21 | 8203 | **60** | 60 | **encrypted** — **ICC RSA priv key: Component DP** |
| 22 | 8204 | **60** | 60 | **encrypted** — **ICC RSA priv key: Component Q** |
| 23 | 8205 | **60** | 60 | **encrypted** — **ICC RSA priv key: Component P** |
| 24 | A006 | **60** | — | **encrypted** — Applicative IDN Key (contact) |
| 25 | A016 | **60** | — | **encrypted** — Applicative IDN Key (contactless) |
| 26 | 8000 | **60** | 30 | **encrypted** — card UDKs AC‖SMI‖SMC (3×16, no KCV) |
| 27 | 9000 | 00 | 09 | final DGI (completion / checksum) |
| 28 | 8001 | **60** | 30 | **encrypted** — card UDKs (2nd set, contactless) |

(P2 0x27/0x28 ordering: 9000 then 8001 — confirm exact tail order against the trace when implementing.)
DGI labels above are from the INTERPRETER trace REM comments (ground truth). CORRECTION 2026-07-15: 8010 is the
PIN (not the ICC key); the ICC RSA private key is the 5 CRT-component DGIs 8201-8205 (PQ/DQ/DP/Q/P), each
DEK-wrapped under the session encryption key. KEY-PAYK/MACIK/ENCK-CONTACT + IDN = the A0xx/8000 key DGIs.

## What this means for the bpr.cpp build

- Framing (P5 emitter) is DONE and correct for all of the above (DGI-agnostic).
- Remaining work = the **DGI content builders**, in two buckets:
  1. **Plaintext DGIs** (A0xx/B0xx/9xxx/0E01/02xx-04xx) — pure logic; internal DFxx/Cx tag layout decoded
     from the trace + values from the ADDONS profile. Testable offline via KAT vs the trace bytes.
  2. **Encrypted DGIs** (8010/820x/8000/8001/A006/A016) — need the DEK session key (SCP02) + the issuer
     UDKs; values are DEK-wrapped. Depends on IHsmClient (task-001.3) and the SCP02 session (task-001.1).
     NEVER commit the real DEK ciphertext to tests — use synthetic values for framing KATs.

Full A002 content (the anchor DGI) is captured verbatim in the trace at the `H01-SMC data = '...'` line
(Spi4MLB2 line ~1048).

## CRITICAL structural insight — A0xx DGIs are FIXED POSITIONAL, not TLV

The generic record DGIs (0201/0301/0401…) are template-70 BER-TLV — self-describing, easy to build.
The M/Chip Advance **A0xx/B0xx DGIs are fixed positional binary structures**, NOT TLV. Example — A002
(DGI len 0x6F = 111 bytes), verbatim from the trace:

```
0368 0368000100 0368000100 0368000100 0368000100 0368000100 000000000000000000000000
0999 0999000100 0999000100 0999000100 0999000100 0999000100 000000000000000000000000
00000000 FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF 42 0000000003680000000109990000
```
Recognizable profile fields appear concatenated by OFFSET (currency 0368, accumulator conversion tables
0999000100…, CDOL1-related-data-length 42 = profile tag C7, FF… limit masks) — but there are NO tag
bytes delimiting them. To build A002 byte-exact you need the **M/Chip Advance CPS field-layout spec**
(field order + widths for the A002 CRM template), which is proprietary and NOT derivable from a single
trace sample with confidence.

Implication for the port: the plaintext A0xx/B0xx builders cannot be safely inferred from the trace alone.
Authoritative options, in order of preference:
  1. The **M/Chip Advance CPS / Card Personalization spec** (Mastercard) — defines each A0xx template layout.
  2. The **Thales DPM / Profile-Converter template files** that turn the ADDONS profile into DGIs — these
     encode the exact ADDONS-tag → A0xx-DGI offset mapping. (The profile is `Addon_PersoTool` output; the
     converter templates are the missing link.)
  3. Failing 1/2: byte-align each A0xx DGI against the trace field-by-field using the ADDONS values as
     anchors — slow, per-DGI, and must be KAT-verified against the trace; residual risk on padding/reserved
     fields. Do this only if the specs are unavailable.

The generic record DGIs (02xx/03xx/04xx) and the framing emitter are unaffected — those are ready to build.

## DECISIVE ARCHITECTURE (2026-07-15) — three DGI classes, three strategies

Decoding the trace shows the ~41 DGIs fall into three classes, each with a different (and for the config
class, much LOWER-risk) build strategy. This supersedes "hand-code 41 byte-exact builders":

1. **Record DGIs — template-70 BER-TLV** (0201, 0301, 0302, 0401, 0402, 0403, 0404, 0E01).
   Self-describing TLV. e.g. the trace's 0201 = `70 81A6 { 9F42=0368, 5F25=011121, 5F24=…, 57 track2,
   5A PAN, 5F34, 5F28, … }`. BUILD from tags (extend the existing build_dgi_0201.. with the FULL tag set
   decoded from each record's template-70 content in the trace). Carries the per-card data. KAT vs trace.

2. **Config DGIs — fixed positional CRM templates** (A002, A012, A022, A007/A017/A027, A008, A009, A00A,
   A005, A00E, B002, B005, B010, B011, B016, B023, 9101, 9010, 9000, A202, AD14). These encode PRODUCT-LEVEL
   risk/limit constants from the ADDONS profile (accumulator currency tables, limits, IAC, control bytes) —
   NOT cardholder data, so they are BATCH-INVARIANT (identical for every card of this product). Do NOT
   reconstruct field-by-field (risky, single-sample). Instead capture each DGI's exact byte block once as a
   **product-config constant** (derived from the profile / verified against the trace) and emit VERBATIM.
   Non-secret (risk params, no keys/PAN — all are P1=00 plaintext), so the product-config table is git-safe.
   A002 partial decode (for documentation) — 111 bytes: Acc1 CurrencyCode(2)=0368, Acc1 ConvTable(25),
   Acc1 Lower/Upper(6+6), Acc2 CurrencyCode(2)=0999, Acc2 ConvTable(25), Acc2 Lower/Upper(6+6), counters,
   Additional Check Table(18)=000000+FF×15, CDOL1-RelData-Len(C7)=42, CRM Country(C8)=0368, PIN Try Limit
   (C6)=01, Max Txn Currency(DF24)=0999, … Exact interior widths need the M/Chip Advance A002 template;
   verbatim-emit avoids needing them.

3. **Encrypted key DGIs — DEK-wrapped** (8010 ICC priv key, 8201-8205, 8000/8001 issuer keys, A006/A016).
   P1=0x60. Values are per-card, DEK-wrapped under the SCP02 DEK session key. BUILD via IHsmClient
   (derive UDKs / gen ICC RSA → wrap under DEK). Needs task-001.1 (SCP02 session) + task-001.3 (HSM).
   NEVER commit real DEK ciphertext to tests — synthetic values only. DEK-wrap primitive DONE (511d2ba).

### RSA cert sub-classes (refined on decode 2026-07-15)
- **0404 (tag 90, Issuer PK Cert, 248B) + 0402 (8F CA index + 9F32 issuer exp)** = issuer-invariant public
  constants → verbatim config (done, byte-exact).
- **0401 (contact) / 0403 (contactless)** = per-card ICC PK Certificate: 9F47 exp / 9F46 cert (176B = N_I) /
  9F48 remainder (42B). ONE ICC keypair (identical 9F48), two certs over the contact vs contactless SDA data.
  Built by perso::oda (bpr.cpp b63fdbd) per EMV Book 2 §6.4 — structurally verified end-to-end offline with a
  test issuer key. Exact trace 9F46 needs the REAL issuer RSA private key (HSM), same gate as VISA2.

## LIVE PERSO RESULTS (2026-07-15) — first end-to-end run on the physical card

Ran perso-live --commit against the UAT Gemalto card. WORKS LIVE: VISA2 auth (ISD EXT AUTH -> 9000),
perso-entry (DELETE + INSTALL[make selectable] -> instance created, SELECT -> 9000, no more 6999), applet
SCP02 (applet EXT AUTH -> 9000), and **31 of the 41 STORE DATA DGIs accepted (9000)** — ALL config/CRM
(A0xx/B0xx), FCI (A001/9101), the 3 records (0201/0301/0302), and CRUCIALLY the RSA cert DGIs
(0401/0402/0403/0404). Two gaps remain, both FORMAT/SPEC (not engine framework):

1. **Encrypted key-loading DGIs → 6A80** (9 DGIs: 8000/8001, 8010 PIN, 8203/8204/8205 ICC-key CRT,
   A006/A016 IDN, 9000 key-KCVs; oddly 8201/8202 pass — unexplained). Loaded via the Thales KMS
   **`stdCPSEmvGeGKOSConfForSecretLoading`** ("computes cryptogram(s) to load PIN, 3DES keys and RSA keys").
   KEY-BLOCK DECODE (from the trace, 2026-07-15):
   - Keys start under KEKs (`G0E01.TEST.PINENC.KEK.01`, `…KEYENC.KEK.01`); the KMS re-ciphers each from the
     KEK to the SESSION encryption key (`SKUDEK`/`SK_ECB` = session key in ECB) and emits a cryptogram.
   - KMS I/O lengths: PIN input `00A5`→ out 16B; 3DES `00AE`→ out 24B (×8 keys); RSA `032F`→ out 688B (5 CRT).
   - **The DGI content matches the engine's format**: symmetric key DGI = the 16-byte 3DES-ECB DEK-encrypted
     key VALUE, concatenated, NO KCV/MAC in the DGI (trace 8000[0:16] == A006 value — same key encrypted).
     The KMS's extra 8 bytes (24 vs 16) are a KCV/MAC used server-side, NOT sent. So `build_key_dgi` = correct
     structure.
   - RULED OUT LIVE (both → 6A80 on all 9): wrapping under the SESSION DEK (session_key const 0x0181) AND the
     STATIC VISA2-diversified DEK (keyId 3). So the DEK CHOICE is not the gap.
   - REMAINING unknown (needs the GeneralOS / M/Chip Advance CPS confidential-DGI spec): either the exact
     secret-loading DEK/derivation (neither standard SCP02 DEK), OR a missing "initialize secret loading"
     command before the encrypted DGIs, OR a per-key-block header the applet parses. This is the deepest
     perso step (secure key injection) and is the LAST functional gap.
2. **0E01 (SFI 14 Record 1) → 6A80** — a profile-specific data record ("Mastercard_DI_GFCX9_MChipAdvance
   Without IDS & SDS & CVC3"). Our verbatim copy doesn't match the freshly-installed instance's expectation.

Card left UNLOCKED (SET STATUS not reached). NET: the whole perso FRAMEWORK is proven live end-to-end; the
remaining work is reproducing two Thales/M-Chip data formats (the secret-loading key block + the SFI-14 record).

## Engine status (2026-07-15): full 41-DGI stream assembles
26 config verbatim + 3 TLV records (byte-exact) + 2 ICC cert DGIs (RSA, structurally verified) + 10 encrypted
key DGIs (DEK-wrap ready). Remaining for a LIVE card perso are EXTERNAL inputs, not engine logic: (a) real
issuer RSA key → real 9F46; (b) VISA2 diversification verified → real session DEK → real 8000/8010; (c) live
PC/SC driver. Engine-side builders + assembler injection points are complete.

Build order to reach a physical-card perso: (2) capture config-DGI product table [git-safe, unblocks most
of the stream] → (1) full TLV record builders from the trace tag sets → emitter assembles config+records →
(3) encrypted key DGIs once SCP02+HSM land → live driver (SELECT→SCP02→INSTALL→STORE DATA→SET STATUS).

## SCP02 wire + DEK-wrap (from ISpi4Mlb2 card-DLL trace, 2026-07-15)

Real per-session wire: `SELECT ISD → INIT UPDATE (80 50 00 00 08 <host chal>) → GET RESPONSE (80 C0) →
EXT AUTH (84 82 00 00 10 <8-byte host cryptogram><8-byte C-MAC>) → DELETE/INSTALL/STORE DATA`.
- EXT AUTH **P1 = 0x00** ⇒ security level 0 for subsequent commands: **STORE DATA is sent CLA=0x80 with NO
  C-MAC** (0× `84E2`, 135× `80E2` in the trace). So the engine's per-command secure-messaging wrap is NOT
  exercised by this perso; the sequencer's CLA-80/no-MAC output is already the wire.
- The key DGIs (8010/820x/8000/8001/A006/A016, P1=0x60) are protected by **DEK encryption of the key values**
  under the SESSION DEK (3DES-ECB), independent of the channel security level. Implemented: bpr.cpp
  `scp02::dek_encrypt` (511d2ba). The session DEK = `session_key(staticDEK, kDerivDek=0x0181, seqCounter)`.

### ✅ RESOLVED (2026-07-15): VISA2 static-key diversification verified live
The card's SCP02 static keys are the ISD master (KVN01, KCV C277BA) **VISA2-diversified** with the 10-byte
INIT UPDATE key-div-data. The KDF is the **GPPro fillVisa layout**: D = kdd[0:2]‖kdd[4:8]‖F0‖keyId‖
kdd[0:2]‖kdd[4:8]‖0F‖keyId, then card key = 3DES-ECB(master, D); keyId 1/2/3 = ENC/MAC/DEK; session keys
via the standard SCP02 derivation. VERIFIED by running `gp.jar --key-kdf visa2 -d --list` on the live UAT
Gemalto card (ACR39U): EXT AUTH -> 9000, channel opened. The engine (`scp02::visa2_diversify` +
`visa2_session_keys`, bpr.cpp 181a2ae) reproduces that live session's **card cryptogram 4E69A8C28F08308D**
AND **host cryptogram F602F36D214BAEF5** byte-for-byte (keystore-gated test Scp02Visa2.ReproducesLiveGpJarSession).
Why the earlier offline probe failed: it used the stale scp02_test kResp1 vector (seq 0003, cryptogram
879A95BF…) which is from a DIFFERENT earlier session/card, not the ISD-KVN01(C277BA) key. NET: the SCP02
session + real DEK are now fully derivable in-engine — real 8000 (UDKs) and 8010 (ICC priv) key DGIs are
unblocked (they still need the per-card ICC RSA key from the ODA path / real issuer key).
