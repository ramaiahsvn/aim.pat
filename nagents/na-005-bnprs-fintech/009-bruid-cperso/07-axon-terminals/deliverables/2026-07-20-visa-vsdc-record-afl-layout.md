# Visa (VSDC 2.9.2) — authoritative record / AFL / GPO-answer layout

**Task:** bruid-cperso task-002.2 (rebuild the Visa AFL/SFI records from the spec)
**Date:** 2026-07-20
**Sources:** `VSDC2.9.2_Personalization_Manual_v1.3.pdf` (§3.14 GPO answers, §3.15 AIP, §3.16 [SFI][rec],
worked example ~p.48) + the card's VPA profile
`OutputFile_..._A0000000031010_DI_VisaDebit.xml` (VIS 1.6.3 / VCPS 2.2.4, "ISC Visa Debit | Online-Only").

> Replaces the INFERRED Visa DGI layout in `perso-live-visa` (mem-020: "AFL is a GUESS"). The AFL and
> AIP are now spec-anchored; the readable-record tag split is per the manual's [SFI][rec] scheme.

## 1. Where AIP + AFL live (NOT in a readable record)

VSDC personalizes AIP (tag 82) and AFL (tag 94) **inside the GPO-answer DGIs**, one per interface/path:

| DGI  | Interface / path                         | AIP (this card) | Presence |
|------|------------------------------------------|-----------------|----------|
| 9104 | VSDC contact, Answer to GPO              | **3800**        | contact  |
| 9115 | qVSDC contactless, online decline no ODA | **0020**        | qVSDC    |
| 9117 | qVSDC contactless, online with ODA       | **2020**        | qVSDC    |

AIP values are taken directly from the profile (three tag-82 entries, categorised `dgi=9115`,
`dgi=9117`, and `category=VSDC`). Manual constraints (§3.15): AIP.Byte1.bit7 = 0 (else DGI rejected);
for contactless GPO answers AIP.Byte2.bit6 = 1 (0020/2020 satisfy this). The profile is "Online-Only"
→ Issuer-authentication bit (byte1.bit3) = 0, consistent with 3800.

For **contact (9104)** the GPO answer = AIP ‖ AFL. For **qVSDC (9115/9117)** the GPO answer additionally
bundles the transaction data elements returned directly in the response (Track2 57, Cardholder Name 5F20,
PAN Seq 5F34, IAD 9F10, AC 9F26, CID 9F27, ATC 9F36, AOSA 9F5D, CTQ 9F6C, FFI 9F6E) — qVSDC returns these
in the GPO answer rather than via READ RECORD.

## 2. The AFL (tag 94) — concrete, from the manual worked example

```
AFL = 08 01 01 00  10 01 04 00  18 01 02 01
       └ SFI1 r1     └ SFI2 r1-4   └ SFI3 r1-2 (r1 in SDA)
```
Each 4-byte entry = (SFI<<3) ‖ firstRec ‖ lastRec ‖ #recsInSDA. This drives contact READ RECORD; only
records declared in the AFL (SFI 1–10) are terminal-readable (manual line 621). Our card can adopt this
record set and emit a matching AFL — the AFL is DP-chosen and must agree with the records actually written.

## 3. Readable records — DGI [SFI][rec], template 70 (§3.16)

`DGI 0xSSRR` = SFI SS, record RR (e.g. 0103 = SFI1 rec3). Data wrapped in template 70, TLV. Tag inventory
the manual assigns to the readable files (per-card items marked ⟨DP⟩ = filled by bruid-dprep, not in the
profile template):

- **SFI 1 rec 1 (DGI 0101):** 70→61→ AID 4F, Label 50, Pref-Name 9F12, Priority 87
- **SFI 2 (DGI 0201-0204):** Expiry 5F24⟨DP⟩, PAN 5A⟨DP⟩, CDOL1 8C, CDOL2 8D, Effective 5F25⟨DP⟩,
  AUC 9F07, PAN-Seq 5F34⟨DP⟩, CVM-List 8E, IAC-Default 9F0D, IAC-Denial 9F0E, IAC-Online 9F0F,
  Country 5F28, Currency 9F42, App-Version 9F08, Cardholder-Name 5F20⟨DP⟩, Track2 57⟨DP⟩, Track1-disc 9F1F⟨DP⟩
- **SFI 3 rec 1 (in SDA):** ODA/DDA data — CAPK-Index 8F, Issuer-Cert 90⟨DP/ODA⟩, Issuer-Exp 9F32,
  Issuer-Remainder 92⟨DP/ODA⟩, SDA-Tag-List 9F4A (=82 only), and for DDA (not CDA) DDOL2 9F49.

Profile-level tags present in THIS profile (shared, not per-card): 4F, 50, 5F28, 8C, 8D, 8E, 9F07,
9F08, 9F0D, 9F0E, 9F0F, 9F49, 9F4A, plus qVSDC config (9F10/9F52/9F56/9F5A/9F68/9F69/9F6C/9F6E) and
the three AIPs. Per-card items (PAN, expiry, effective, PSN, name, tracks, ODA certs) come from dprep.

## 4. SELECT / FCI + PPSE

- **DGI 9102** = ADF FCI (SELECT response for A0000000031010): A5 → PDOL 9F38 etc. (profile 9F38 present).
- **DGI 9200** = DKI/CVN/IDD options for IAD construction (mandatory, §3.15) — value 9200 0C 9F10 09 ...
- PPSE (2PAY.SYS.DDF01) entry is a card-manager concern, separate from the applet data.

## 5. Delta vs the current `perso-live-visa` (what .2 corrects, what .4 finalizes)

CORRECTED now (spec-anchored, offline-verifiable):
- GPO answers carry AIP **and** the real **AFL 080101001001040018010201** (was: bare `9115 AIP=0020`).
- AIPs use the profile's 3800 (contact) / 0020 (9115) / 2020 (9117); bit constraints checked.

FINALIZED LIVE in task-002.4 (needs per-card data + a live GPO/READ-RECORD probe):
- The exact readable-record tag split across SFI2 rec1-4 / SFI3 rec1-2 once dprep's per-card blob
  (PAN/expiry/PSN/name/tracks/ODA certs) is wired in.
- The qVSDC 9115/9117 data-element bundle (AC/ATC/AOSA are runtime; personalize the static subset).
- Confirm the applet accepts this AFL/record set (GPO returns the AFL, AFL-driven READ RECORD succeeds),
  mirroring how the MC card was self-verified (mem-024).

## 6. Version caveat

Manual is VSDC 2.9.2 on GFCX17.0; the live card is GCX7_5 (same platform-version gap noted for MC,
mem-021). The [SFI][rec] + GPO-answer DGI scheme is EMV-CPS standard and expected to hold; verify live.
