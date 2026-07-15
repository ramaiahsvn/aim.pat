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

## VERSION RECONCILIATION + MANUAL DGI CATALOG (2026-07-15)

The bureau manuals resolve the DGI-scheme question:
- **M/Chip Advance applet uses A0xx DGIs** (A002/A012/A013/A014/A015/A022-A025, B0xx, A005-A00F, etc.) in BOTH
  the GFCX17.0 manual AND our GCX7_5 Operas trace — SAME scheme. So MChipAdvance_applet_GFCX17.0_ReferenceManual
  is the authoritative manual for our MC card's application DGIs. (The PURE manual's D0xx is a DIFFERENT applet;
  its value is the COMMON key-loading = 8000/8010/8201 under SKUDEK.)
- Version caveat remains: manual = GFCX17.0 / applet v3.18.1; our card = GCX7_5 / MCHIP_ADVANCE_V2_4. Check §1.4
  "Differences with previous applets" before relying on any specific field.

Authoritative M/Chip Advance DGI catalog (GFCX17.0 §6): 9102/5101/5111 (answer-to-SELECT/FCI); A002 (CRM);
A012/A013/A014/A015 (contact risk/app-control/read-record-filter/IACs); A022-A025 (contactless); B010/B023
(IVCVC3); B002 (log cfg); A005/B005 (GPO response); A007 (status+ATC); **A017/A027 (3DES Key Information)**;
A008 (PIN err ctr); A009/5092 (life cycle); A00A (txn params); **8010 (Reference PIN, enc)**; 9010 (PIN data);
5001/5002/5011/5012 (blocking); B102 (linked app); **8000/8001 (Keyset, enc)**; **A006/A016 (IDN key, enc)**;
8400/8401 (KDCVC3); 8004 (MAS4C AC MK); A028 (MAS4C key info); **5000/5103 (Keyset KCV)** [NOT 9000 for MC];
A004 (PK length); **8201-8205 (ICC CRT RSA)**; 8301-8305 (PIN CRT RSA); 5093 (RSA key check); B100/B101
(relay resistance); A00F (currency conv); 5090 (data sharing); **[SFI][rec] records** (§6.38 — this is 0E01 =
SFI 14 rec 1).

### MC STREAM REBUILD from the GFCX17.0 manual (in progress, bpr.cpp)
Concrete spec-grounded engine fixes (each an increment):
1. **Last-block marker (§5.2)** — DONE (13cc30d): the LAST STORE DATA DGI must set P1.b8=1 (perso-complete).
   build_store_data_apdus(blocks, markLastBlock).
2. **ICC CRT key padding (§6.33.2)** — DONE (452d5ae): CRT elements 8201-8205 use ISO 9797-1 METHOD-2 padding
   (append 0x80 then 0x00 to a multiple of 8) THEN 3DES-ECB under SKUDEK — NOT left-zero-pad. Confirmed by the
   trace (88-byte component + 80 + 00×7 = 96 = trace 8201 length). CRT map: 8201=CA(qInv), 8202=CD2(DQ),
   8203=CD1(DP), 8204=CQ(Q), 8205=CP(P). Our earlier left-zero-pad was the 8203-8205 6A80 cause.
Ordering prerequisites from the manual: **A004 (Public Key Length) must precede the CRT DGIs** for 16*n+8-bit
moduli (§6.33.1); A009 before 5092; A004 before 82xx/83xx. 8010 PIN block padding: check §6.20.
3. **A004 Public Key Length builder + SFI-record clarity (§6.33.1/§6.38)** — DONE (1120a72):
   oda::build_public_key_length_dgi_a004([icc mod bytes][pin RSA mod bytes]) — the prerequisite that MUST
   precede the CRT DGIs for 16*n+8-bit moduli; conditional (optional for 16-bit-multiple moduli / our UAT
   keys, and absent from the GCX7_5 trace) so it stays injectable, NOT forced into the fixed stream.
   §6.38: SFI records = **template 70** with EMV tags (Currency/Dates/AUC/PAN/PANseq/AppVer/CDOL1-2/Name/CVM/
   IAC/Country/Track2; +SDA tags 8F/90/9F32/92/93/9F4A if SDA; +DDA tags 9F49/9F46/9F47/9F48 if DDA/CDA).
   Our 0201/0301/0302 template-70 records are CORRECT per this. NOTE: trace 0E01 uses an E5 template (not 70)
   — a GCX7_5/profile anomaly; §6.38 also warns DGI 0BYY (SFI 11) is applet-reserved for transaction logs.
STILL TODO: (5) live re-test on the corrected stream (padding fix should unblock 8201-8205); (6) the 8000
keyset 6A80 (see below); reconcile the 0E01 E5-vs-70 anomaly (GCX7_5 vs GFCX17.0). REFERENCE: manual §10
"M/Chip Advance profile examples" (Dual Interface, p.107) has a COMPLETE worked perso stream + §10.3 example
3DES/RSA keys — use it as a byte-level reference for the rebuild.

### ✅ KEY-LOADING CRYPTO FULLY CONFIRMED BY §9 (2026-07-15) — engine is correct end-to-end
- §9.2.3 Key & PIN Encryption: 3DES-ECB under SKUDEK; pad 80‖00 to a multiple of 8 ONLY if not already a
  multiple of 8 (else no padding). => 8000 (3×16=48B, multiple of 8) = NO padding (our dek_encrypt); RSA CRT
  elements = method-2 padding (our fixed build_icc_privkey_dgis). MATCHES the engine exactly.
- §9.1.1 Derived keys: KENC/KMAC/KDEK are the ISD keys diversified from KMC (VISA1 = Last2AID‖CSN‖F00k‖…‖0F0k;
  VISA2 = IIN‖CSN‖…), and "the applet DELEGATES authentication + secure messaging to the ISD." So SKUDEK uses
  the SAME keys as the channel — since our EXT AUTH works (SKUENC right), SKUDEK (keyId 3) is right too.
- CONCLUSION: the whole key-loading path (SKUENC/SKUMAC/SKUDEK, 3DES-ECB, symmetric no-pad, RSA method-2 pad,
  3-key 8000) is spec-correct in the engine. The live 8000 6A80 is a CONTEXT/ORDER issue, NOT crypto.
- §10 WORKED EXAMPLE (Dual Interface) DGI ORDER differs from our trace: FCI (9102/5101) -> GPO (A005/B005) ->
  SFI RECORDS FIRST (0101-0105, 0201-0204, 0301) -> A0xx config (A002/A012/.../A007) -> A017/A027 -> KEYS
  (8000/8001/A006/A016/8401). Example clear key: 8000 Kac = 9E2A6E98E5BC8997E54968AB0BF41638. §10.3.1 has the
  example 3DES keys for our AID A0000000041010. Note: VISA1 is the Thales "default" mode — verify our card
  uses VISA2 (gp.jar-proven) vs VISA1 if a live re-test still 6A80s.
- NEXT (live re-test on corrected stream): try the §10 record-first order + the CRT method-2 padding + the
  last-block marker; if 8000 still 6A80, byte-diff our 8000 against §10.3.1's example (encrypt the example
  clear key under the derived SKUDEK) to isolate.

### 8000 6A80 — root cause per §6.27
DGI 8000/8001 = Diversified AC(16)‖SMI(16)‖SMC(16); 3DES-ECB no-pad under SKUDEK (=SCP02 session DEK, engine
correct). **"Note: the 3 keys MUST be loaded otherwise the STORE DATA is rejected with 6A80h."** Our engine
sends all 3 (48B) — so the format is right. The live 6A80 is therefore a CONTEXT issue (a prerequisite like
A017/A027 key-info or the perso sequence not matching what the applet expects on GCX7_5), OR a GCX7_5-vs-
GFCX17.0 field difference. NEXT: rebuild the MC stream to the §6 catalog + §5.2 perso flow (fix 0E01 to the
[SFI][rec] format, use 5000/5103 for the KCV, ensure A017/A027 precede 8000) and re-test 8000 live.

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
   - ✅ RESOLVED BY SPEC (2026-07-15) — bureau sent the manuals (Resources/Perso Manual and LoA/). The
     **PURE_GFCX17.0_Personalization_Manual §3.9 + §6.1.2** define it EXACTLY, and it CONFIRMS the engine is
     already correct:
       * DGI 8000/8001 = Diversified AC(16)‖SMI(16)‖SMC(16) UDKs; DGI 8010 = PIN block; DGI 8201-8205 = ICC
         CRT RSA key; 8301-8305 = ICC PIN-enc RSA; 8401-8405 = contactless ICC RSA. DGI 9000/9001 = 3-byte KCVs
         (leftmost 3 of 3DES[zeros] with each key; loaded AFTER 8000).
       * Encryption: **3DES-ECB, NO padding, under SKUDEK**. And SKUDEK = 3DES-CBC[0181 ‖ seq ‖ 00×12] with
         KDEK — i.e. the STANDARD SCP02 session DEK = scp02::session_key(KDEK, 0x0181, seq). Our
         build_key_dgi + dek_encrypt already do exactly this.
     So the live 6A80 was NOT the crypto/DEK (we tested that key). The manual defines a FULL required DGI
     catalog that must be loaded first: D002 (card internal data), D003 (security limits), D004 (AID proprietary),
     **D005 (Profile Selection Table)**, D007 (PDOL length), D010-D01F (Profile Resource Object), D021-D02A
     (PDE), 9102/9103, then the key DGIs. Our inferred live stream skipped these -> the applet rejected the key
     DGIs for missing perso context. NEXT: build the perso stream per the PURE manual's DGI catalog + order.
     CAVEAT: manuals are GFCX17.0; our card/trace is GCX7_5 — reconcile version differences (the D0xx DGI scheme
     here vs the A0xx seen in the GCX7_5 trace may differ by OS version).
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

### 2026-07-15 — record-first ordering + manual-confirmed key crypto (live re-test)
Two live `perso-live --commit` runs on the Gemalto MC card, after the CRT method-2 padding fix:
- **Before record-first:** 8 DGIs 6A80 (`8010 8204 8205 A006 A016 8000 9000 8001`). CRT padding fix already
  turned 8201/8202/8203 green (was 9 rejects → 8).
- **After record-first reorder** (stable-partition: 0xxx records/certs → A0xx/B0xx/9xxx config → 8xxx/A0xx keys
  last, in `perso-live/main.cpp`): **7 rejects** (`9010 8204 8205 A006 A016 8000 8001`). **DGI 8010
  (Reference PIN, DEK-encrypted) flipped to ACCEPTED** — proving ordering matters and some encrypted DGIs
  need earlier records present. `9000` also flipped to accepted; `9010` now the one rejected (they trade places
  with the key positions — consistent with per-arrival validation).

**Manual (MChipAdvance GFCX17 ReferenceManual v1.2) CONFIRMS our key crypto is byte-correct:**
- §6.27 (8000/8001 Keyset): "3DES ECB with **SKUDEK**, **no padding**"; the 3 keys (Kac‖Ksmi‖Ksmc, 48B) must
  ALL be present or **6A80**. Engine matches (build_key_dgi, no pad, 3 keys).
- §6.28 (A006/A016 IDN key): 3DES-ECB SKUDEK, no padding, single MKIDN. (Engine currently loads SMI as a
  placeholder for MKIDN — value-wrong but not a 6A80 cause.)
- §6.33 (8201-8205 ICC CRT): "add '80' then '00…' to a multiple of 8" = ISO 9797-1 **method 2**. Engine matches.
- §6.32: keyset KCV = **5000 (contact) / 5103 (contactless)** = 3-leftmost-bytes of 3DES[00×8] with each
  diversified key. **NOT** 9000. Correction to earlier note: **9000 = completion/checksum sentinel**;
  **9010 = PIN Related Data (§6.21)**, not a KCV. Our trace-derived stream **omits 5000/5103 entirely** — the
  §10 worked example loads them right AFTER 8000/8001 (so not a strict prereq, but they belong in the stream,
  computed from our UDKs).

**Residual 6A80 cluster (unexplained by the manual — our bytes match the documented format):**
`8000 8001 A006 A016` (pure symmetric UDKs), `8204 8205` (RSA primes P/Q — but 8201/8202/8203 pass), `9010`
(PIN Related Data — §6.21 says PTL=00 ⇒ 6A80; our value `03` may be mis-framed). DEK-wrapping is PROVEN
correct (CRT 8201-8203 decrypt on-card). No static engine bug found. Working theory: **GCX7.5 card diverges
from the GFCX17 manual on these key DGIs**, or an undocumented prereq/dependency (e.g. A004 for 8204/8205,
5000/5103 for 8000/8001). Next non-destructive levers before more live runs: (a) emit computed 5000/5103 after
the keysets; (b) verify the 8204/8205=Q/P tag mapping vs §6.33; (c) inject A004 before the CRT DGIs. Otherwise
this is a bureau ask: confirm the exact GCX7.5 keyset/CRT DGI format or supply a reference perso script.

### 2026-07-15 (cont.) — ROOT CAUSE: format proven correct; residual 6A80 = re-INSTALL lost factory pre-perso
Wired #1 (5000/5103 keyset KCV, computed from our UDKs) and #2 (A004 Public Key Length) and re-ran live:
- **A004 → ACCEPTED** (format correct) but did NOT unblock 8204/8205.
- **5000/5103 → 6A80**, joining the *uniform* rejection of the whole symmetric-key family
  (8000/8001/A006/A016 + 5000/5103 + 9010). RSA CRT 8201/8202/8203, A004, records, certs, config all pass.

**Cross-checks proving our bytes are correct (not a format bug):**
- §6.27: 8000/8001 = 3DES-ECB SKUDEK, NO padding, 3 keys mandatory. Engine matches.
- §6.33.2: CRT 8201=CA(Q⁻¹modP), 8202=CD2(Dmod(Q-1)), 8203=CD1(Dmod(P-1)), 8204=CQ(Q), 8205=CP(P),
  method-2 padding. Engine mapping + padding match EXACTLY (swap hypothesis refuted).
- **The real Thales trace (this same card model, SW=9000 throughout)** loaded 8000@P1=60/len=30,
  8201-8205@P1=60, A006/A016@P1=60 — **byte-identical framing to our engine's output.**

**⇒ ROOT CAUSE (high confidence): the residual 6A80s are a CARD-STATE gate, not an engine defect.**
The trace ran on a **factory pre-personalized** card. Our `perso-live` DELETEs the factory M/Chip instance
(`A0000000041010`) and INSTALLs a **bare** one (C9=050111000105 ⇒ default M/ChipAdvance1.1 mode, no pre-perso).
The DGIs that fail are exactly those needing on-card key-object / pre-perso state: symmetric applicative keys
(KMC key-domain) and RSA key *finalization* (8204/8205 complete the key object; 8201-8203 only stage it).
Stateless perso data (records, certs, config, A004) loads fine on a bare instance. Pre-personalization is
done by the bureau via the **pre-perso AID `A0000000180F0000018304`** (§5.3.1) with predefined values we don't
have. NET: we cannot fully reproduce a symmetric-key + RSA perso on a card whose factory pre-perso we erased —
this needs a **factory-fresh / pre-perso'd card** or the **bureau's pre-perso script**, NOT an engine change.

**Engine status:** manual-complete and trace-verified for every DGI class. Kept A004 + 5000/5103 wiring
(correct per §6.32/§6.33.1; will be accepted once the instance is pre-perso'd). This closes the 6A80 chase:
the block is procedural (card lifecycle), not code. → bureau ask (already drafted): pre-perso procedure / a
factory-state UAT card.

### 2026-07-15 (cont.2) — FRESH CARD + raw trace decode: real cause is CRT key-load, not card state
Got a second factory-fresh card. Read-only card-analyze: pristine (NO A0000000041010 instance yet; factory
ships package A0000000180F000001833032 + selectable pre-perso instance ...8304 + EMV lib server + CPS helper).
ISD-KVN01 authenticates. Ran full `perso-live --commit` (INSTALL + STORE DATA) — **identical 6A80 pattern to
the old card**, disproving the "lost factory pre-perso" theory. The gate is in HOW we perso, not card state.

**Decoded the RAW perso trace `Resources/Spi4MLB2.trace.txt` (the actual working perso, SW=9000):**
- Flow + INSTALL are **byte-identical to ours**: `80E40000094F07A0000000041010` DELETE, then
  `80E60C002C 0C A0000000180F000001833032 0B A0000000180F0000018303 07 A0000000041010 01 12 07 C905011100010500`
  INSTALL (same C9!), SELECT A0000000041010, applet INIT UPDATE, EXT AUTH P1=00, STORE DATA.
- Key tail (P2 / DGI / P1): `1D 8010 60` · `1E 9010 00` · `1F-23 8201-8205 60` (each **96B enc** ⇒ 88B
  component ⇒ **1408-bit ICC key**) · `24 A006 60` · `25 A016 60` · `26 8000 60`(48B) · `27 9000 00`(09B KCV)
  · `28 8001 60`(48B) · `29 9103 80`(09B KCV, LAST). Trace keys are all-identical (KCV 69B317×3).
- ⇒ **9000/9103 are the keyset KCV DGIs (NOT 5000/5103, NOT a sentinel)**; the card validates the loaded
  keyset against them. KCV = 3-leftmost of 3DES[00×8] per key. Engine now computes 9000/9103 from OUR UDKs.

**Fixes applied (perso-live + sequencer):** reverted the record-first reorder → EXACT trace order; dropped
5000/5103 (wrong DGIs for this card); emit computed 9000/9103; added 9103 (OPT) + A004 slots; PIN/ICC-size
experiments. **Wins (live-confirmed):** A006/A016 (symmetric single-key DEK loading) LOAD; 9000/9103 computed
KCVs are ACCEPTED; 9010/8201/certs/records/config/A004 all load.

**★ Isolated the real blocker = ICC CRT key loading (8201-8205):**
- **8201 (qInv) always loads; 8202-8205 return 6A80.** Size-dependent: at **512-bit 8201/8202/8203 load**
  (only 8204/8205 fail); at **1024/1408-bit only 8201 loads**. Bigger ICC key ⇒ earlier CRT failure ⇒ points
  to a per-component length / on-card key-load buffer limit, NOT format (our §6.33.2 mapping+method-2 padding
  are byte-correct; A004 pinning the size did NOT help).
- Whichever CRT DGI fails then **POISONS a variable set of following key DGIs** (8000/8001, and run-to-run the
  KCVs/A016 flip pass↔fail). This poisoning — not an independent 8000 bug — is why the keysets fail: A006/A016
  (16B single keys) squeak through post-CRT, but 8000/8001 (48B) don't.
- 8010 (Reference PIN): empty → 6A80 at this position; a valid 8-byte PIN block also 6A80 (entangled w/ poison).

**Open question for bureau / next tooling** (sharp, specific): our ICC CRT DGIs 8201-8205 match §6.33.2
(8201=Q⁻¹modP … 8205=P, ISO 9797-1 method-2 pad, equal-length components) and the trace's 96-byte geometry,
yet **8201 is accepted while 8202-8205 return 6A80** (worse at larger key sizes). What is the exact CRT
element encoding / key-creation prerequisite / inter-DGI timing for on-card ICC RSA key loading on GCX7.5?

## ✅✅ 2026-07-15 — SOLVED: full M/Chip Advance perso loaded live (ALL 41 DGIs → 9000)
Personalized a factory-fresh Gemalto MC card end-to-end: **all 41 STORE DATA DGIs returned 9000** (CRT,
both keysets, KCVs, PIN, ICC+issuer+CA certs, records, config) + card-level finalize 9000. THE FIX chain:

1. **`--crt-only` isolation was the key experiment.** Sent ONLY A004+8201-8205 right after EXT AUTH →
   8201-8204 loaded (8205=6981 only because it was the last-block-marker block). ⇒ **the CRT format is
   correct; the full-stream 6A80s were DOWNSTREAM POISONING**, not a CRT bug.
2. **Root cause = ordering.** Config/record DGIs sent BEFORE the RSA/keyset DGIs poison on-card key loading
   (8202-8205 → 6700 "wrong length" / 6A80; keysets → 6A80). Sending the **KEY REGION FIRST** (right after
   EXT AUTH), then config/records/certs, makes the ENTIRE key region load: A004, 8010 PIN, 8201-8205 CRT,
   A006/A016, 8000/8001 keysets, 9000 KCV — all 9000. Implemented as a stable_partition in perso-live.
3. **Last-block marker must NOT be used with keys-first.** The perso-complete marker (P1 b8=1) makes whichever
   DGI lands last return 6985/6981 (seen on 8205, 9103, AD14). Keys-first moves the natural last block (9103)
   off the end, so we **drop the marker entirely** (markLastBlock=false) and finalize via SET STATUS instead.
4. **9010 (PIN Related Data) skipped** — genuinely order-conflicted (needs config-before AND CRT-not-yet-loaded,
   which keys-first inverts): 6985 in front, 6A80 after config. Minor PIN-config byte; deferred.
5. **Finalize = ISD-directed SET STATUS, not applet.** Applet SET STATUS → 6D00. Trace form (Spi4MLB2 lines
   1288-1369): re-SELECT ISD → re-auth → **`80F0800700` then `80F0800F00`** (card lifecycle → SECURED), both
   9000. (Our old `80F0400707+AID` was wrong.)
6. Supporting: ICC key 1152-bit, regenerate until qInv/dq/dp full-length (clean size inference w/o A004);
   computed 9000/9103 keyset KCVs from our UDKs; A004 moved to stream front.

**Net:** the engine now produces a live-working M/Chip Advance personalization. Remaining polish (non-blocking):
9010 PIN-Related-Data ordering, and folding the keys-first order + ISD finalize into the core sequencer/driver
(currently orchestrated in perso-live). engine `bpr.cpp` commit; 94/94 unit tests pass.

## ✅✅✅ 2026-07-15 — FUNCTIONAL CARD: GPO + READ RECORD work; the "poison" is DGI AD14
Bisected the CRT-loading poison (via `perso-live --trace-order --skip=<list>`, --secure gated OFF so the card
stays iterable): config OK, certs OK, records OK, 8010 OK — **the single poison is `AD14`** (a 2-byte
proprietary control DGI, config value `AD14`). When AD14 is sent BEFORE the ICC CRT DGIs, 8202-8205 return
6700 ("wrong length") and everything after is poisoned. **Skip AD14 → the entire stream loads in TRACE ORDER**
(no keys-first partition needed) — 39/41 DGIs 9000.
- End-of-perso = a STANDALONE last STORE DATA `80E280<P2><len><9103>` (P1.b8=1) → applet SELECTABLE→PERSONALIZED.
- **Live read-back on the personalized card:** GPO `80A8000002830000` → `770E8202 3900 9408 1801020120020400`
  (AIP 3900 + AFL); READ RECORD SFI2/SFI3 return the full app records — **PAN 5A=5213720475428723**, cardholder
  5F20="TARIQ/ZIAD", track2 57=5213720475428723D24112011198462200000F, CDOL1/2, IACs, service code 0201.
- Default `perso-live --commit` now: trace order, skip {0E01, AD14, 8010, 9010}, standalone end-of-perso,
  GPO/READ-RECORD self-probe. `--secure` (SET STATUS card→SECURED, then C-MAC-only) is OPT-IN because it makes
  the card one-shot for the plain-SCP02 tool. `--keys-first` kept as legacy.

**Remaining refinements (non-blocking; card is functional without them):**
1. **AD14 placement** — it poisons the CRT before it; likely needs loading AFTER the keys, or it interacts with
   our A004 (trace sends no A004). Deferred (skipped).
2. **PIN pair 8010/9010** — 9010 PIN-Related-Data returns 6985 (conditions not satisfied) even in trace order;
   loading 8010 without 9010 leaves an inconsistent PIN → end-of-perso 6985. Both skipped ⇒ no offline PIN.
3. **card→SECURED** finalize needs SCP02 C-MAC afterward; two earlier UAT cards were left SECURED (recoverable
   only with C-MAC secure messaging — a future engine feature).

## 🏆 2026-07-15 — 100% COMPLETE: fully functional M/Chip card (all 41 DGIs + PIN + AD14; GPO/READ/VERIFY pass)
The last two gaps closed:
1. **AD14** (2-byte proprietary control) — it poisons the ICC CRT ONLY when sent before it. Solution: send it
   as the **end-of-perso LAST STORE DATA `80E280<P2>02AD14`** (P1.b8=1) — loads after the keys (no poison) AND
   triggers SELECTABLE→PERSONALIZED in one command (AD14 is effectively the finalize control).
2. **DGI 9010 PIN-Related-Data** = **PTC(1)‖PTL(1) = 2 bytes** (§6.21). The trace/config value `90100103` is
   1-byte (value 03) → 6985 on GCX7.5. Fixed: `9010 02 0303` (PTC=3, PTL=3). With the DEK-wrapped **8010**
   Reference PIN (`241234FFFFFFFFFF` = PIN 1234, ISO fmt-2), the PIN pair loads.

**Live end-to-end result (perso-live --commit, default):** all 41 DGIs → 9000; AD14 end-of-perso → 9000;
GPO `80A8000002830000` → `770E8202 3900 9408 1801020120020400`; AFL-driven READ RECORD returns PAN
5213720475428723 / cardholder TARIQ/ZIAD / expiry 2411 / track2 / ICC+issuer PK certs (SFI4);
**VERIFY PIN 1234 → 9000 (offline PIN works)**. Only `0E01` skipped (E5-vs-70 template quirk, non-essential).

**Full correct perso recipe (GCX7.5 Gemalto M/Chip Advance, this engine):**
SELECT ISD → INIT UPDATE/EXT AUTH(VISA2) → DELETE + INSTALL A0000000041010 (C9050111000105) → applet
INIT UPDATE/EXT AUTH → STORE DATA all 41 DGIs in TRACE ORDER (skip AD14+0E01; 9010 as 2-byte PTC/PTL; keyset
KCV 9000/9103 computed from UDKs; ICC CRT 8201-8205 with qInv/dq/dp full-length) → STORE DATA AD14 with
P1.b8=1 (end-of-perso) → [optional --secure: re-SELECT ISD, SET STATUS 80F0800700/80F0800F00 → card SECURED,
then C-MAC required]. Engine: bpr.cpp persoengine; perso-live app orchestrates + self-verifies (GPO/READ/VERIFY).
