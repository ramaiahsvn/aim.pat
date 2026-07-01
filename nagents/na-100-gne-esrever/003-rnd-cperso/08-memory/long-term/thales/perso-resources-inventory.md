---
name: Perso Resources Inventory (Card Profiles, Embossing Spec, Vendor Traces)
description: Structural index of the gating perso inputs delivered to trp1002.cperso.thales/Resources/ on 2026-07-01 — MC+Visa card profiles, Tri-Badge PURE embossing spec+sample, and Gemalto+TechTrex APDU traces. Labels/structure only; NO PANs/keys.
type: project
---

> Delivered by user on **2026-07-01** into `trp1002.cperso.thales/Resources/` (untracked; git-ignored
> as of same date — folder holds real PANs/PII/track data, PCI Card Production scope, NEVER commit).
> This doc records **structure only** — no cardholder data, no key values, no track data.
> These resources CLOSE the card-profile-spec + embossing-format gaps that blocked task-001 and task-002.

## Inventory

| File | Kind | Source / Vendor |
|---|---|---|
| `Card Profiles/MC/PFL_20251009_071246508_Addon_PersoTool_1_MCC.xml` | MC M/Chip perso profile | Mastercard Profile Converter (`ADDONS`) |
| `Card Profiles/Visa/OutputFile_…_VPA_4000048094.v1_A0000000031010_DI_VisaDebit.xml` | Visa perso profile + DGI map | VPA 4.1 (VCPS 2.2.4) |
| `Tri-Badge PURE Embossing File specifications V3.0.docx` | Embossing field-layout spec | — |
| `R06_…_Enriched_Pat.txt` | Sample embossing file (3 records) | SENSITIVE — real PAN/PII |
| `GemaltoCard_Traces_PrePersoInstant_McQi.LOG` | APDU perso trace (MC+Qi instant) | Gemalto / Thales |
| `TechTrex_Logs.LOG` | Perso DP-out trace (451 KB) | TechTrex — SENSITIVE, real track1/2 |

## MC profile — `ADDONS` XML (Mastercard Profile Converter)
- Structure: `ADDONS > WORKSHEET[NAME] > ELEM[NAME, VALUE, TAG]`.
- Worksheets: **fci, internal, recordcontact, recordcontactless**.
- AID (DF Name, tag 84): **A0000000041010** (Mastercard). App Label (50) = "Mastercard".
- EMV config populated: CDOL1/CDOL2 (8C/8D), CVM List (8E), Log Format (9F4F), accumulators
  (currency conversion tables D1/D2/DF17), Additional Check Table (D3), PIN Try Counter (9F17).
- **Key fields present but EMPTY (labels only)** — AC/SMI/SMC/ICC-DN Master Key ×(Contact, Contactless),
  Key Derivation Index. Guardrail-safe: profile carries NO key values.

## Visa profile — VPA 4.1 XML
- Structure: `config > template > tagelement{tagname[category, dgi], tag, taglength, tagvalue}`.
- Attributes: vparelease 4.1, vcpsversion 2.2.4, visversion 1.6.3, region CEMEA, magstripe Y,
  profile "ISC Visa Debit | Online-Only", profileid 4000048094.v1, issuer "International Smart Card Company".
- AID (4F): **A0000000031010** (Visa). App Label (50) = "Visa Debit".
- **32 `tagelement` blocks. Carries explicit `dgi=` attributes** (seen: 9115, 9117 for qVSDC AIP tag 82).
  → This is the DGI layout task-001.2 / task-002 needed.

## Embossing sample vs spec — WIDTH DELTA ⚠️
- Sample `R06_…Enriched_Pat.txt`: **3 records, exactly 21,228 chars/record**, LF-delimited.
- Task-001 recorded spec V3.0 as **~21,157 chars/record** → **+71 char delta**. RECONCILE against the
  V3.0 docx (likely enriched fields the parser doesn't yet account for) before trusting the parser.

## GlobalPlatform secure channel = **SCP02** (resolves task-001.5)
- Gemalto trace shows `80 50 0000 08 <8-byte host challenge>` (INITIALIZE UPDATE) → `61 1C`
  (28-byte response = key-div-data + key-info + card-challenge + card-cryptogram) → SCP02 signature
  (NOT SCP03). Confirmed for the instant-perso MC+Qi line.

## Perso APDU sequence (ground truth, from Gemalto trace — command headers only)
Full GP + EMV perso flow observed (counts approx):
- `00A4 04/00` SELECT · `80 50` INIT UPDATE · `84 82` EXTERNAL AUTHENTICATE (SCP02)
- `80 E6 0C` INSTALL [for perso] · `80 E4` DELETE · `80 F2` GET STATUS · `80 F0` SET STATUS
- `80 E0` **PUT KEY** (~35×) · `80 E2 80xx` **STORE DATA** · `00 D6` UPDATE BINARY (~21×)
  · `00 E2` APPEND RECORD (~24×) · `80 C0` GET RESPONSE
→ Reference sequencer for the planned C++ EMV engine (task-002.2/.3). TechTrex log gives a second,
  independent vendor perso trace for cross-vendor diff.

## What remains outstanding after this delivery
- **Test keys / KCVs** (task-001.3) — still needed (IDs/labels only per guardrails).
- **Thales INTERPRETER reference manual** (task-001.4) — still needed to convert `.spi` pseudocode.

See [[emv-engine-plan]] for the C++ engine decisions this unblocks, and the task files
`02-cell-body/planning/todo/task-001-bprdataprep.yaml` / `task-002-cperso-thales.yaml`.
