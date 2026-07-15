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
| 1D | 8010 | **60** | 08 | **encrypted** — ICC RSA private key (DEK-wrapped) |
| 1E | 9010 | 00 | 01 | |
| 1F | 8201 | **60** | 60 | **encrypted** — key/PIN block |
| 20 | 8202 | **60** | 60 | **encrypted** |
| 21 | 8203 | **60** | 60 | **encrypted** |
| 22 | 8204 | **60** | 60 | **encrypted** |
| 23 | 8205 | **60** | 60 | **encrypted** |
| 24 | A006 | **60** | — | **encrypted** — keyed (contact) |
| 25 | A016 | **60** | — | **encrypted** — keyed (contactless) |
| 26 | 8000 | **60** | — | **encrypted** — issuer keys |
| 27 | 9000 | 00 | 09 | final DGI (completion / checksum) |
| 28 | 8001 | **60** | — | **encrypted** — issuer key (2nd) |

(P2 0x27/0x28 ordering: 9000 then 8001 — confirm exact tail order against the trace when implementing.)

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
