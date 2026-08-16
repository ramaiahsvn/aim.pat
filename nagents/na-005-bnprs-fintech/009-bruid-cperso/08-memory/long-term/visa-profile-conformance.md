# Visa VSDC — issuer profile vs our engine output (AUTHORITATIVE conformance list)

Established 2026-08-16 from the vendor-supplied sources, which OUTRANK any value inferred from a
reference card or a trace. When these disagree with an inference, the profile wins.

**Sources**
- Card profile (authoritative per-product): `trp1002.cperso.thales/Resources/Card Profiles/Visa/
  OutputFile_IRAQ_InternationalSmartCardCompany_VPA_4000048094.v1_A0000000031010_DI_VisaDebit.xml`
  — VPA 4.1 output, product "Visa Debit", profile **"ISC Visa Debit | Online-Only"**,
  profileid 4000048094.v1, approval **LBTHAL05289A**, VIS 1.6.3 / VCPS 2.2.4, region CEMEA,
  country 0368, `magstripe="Y"`, BINs `43182600;41824400;41776302;42428900`
  (our test PAN 4177630226449323 → BIN 41776302 ✓ in profile).
- Perso manual: `Resources/Perso Manual and LoA/VSDC2.9.2_Personalization_Manual_v1.3.pdf`.

**Profile-level facts that shape everything else**
- `contactonlineonly="Y"` and `contactlessonlineonly="Y"` — this is an **Online-Only product**.
  Offline approval is not merely blocked by the terminal's floor limit 0; it is not the design.
  Chasing offline approval for this profile is wrong by construction.
- `contactcvms="[Online PIN,Signature,No CVM Required]"`
- `contactlesscvms="[Online PIN,Signature]"`
- `contactlesstxnpath="[qVSDC Online Decline,qVSDC Online ODA]"` → matches DGI 9115 (AIP 0020) and
  9117 (AIP 2020), which the engine already emits.

## Conformance table — engine vs profile

| tag | profile (authoritative) | our engine | verdict |
|-----|-------------------------|-----------|---------|
| 4F | A0000000031010 | same | ok |
| 50 | "Visa Debit" | same | ok |
| 5F28 / 9F57 | 0368 | same | ok |
| 82 VSDC | 3800 | same (DGI 9104) | ok |
| 82 qVSDC | 0020 (9115) / 2020 (9117) | same | ok |
| 8C | 9F02069F03069F1A0295055F2A029A039C019F3704 | same | ok |
| 8D | 8A029F02069F03069F1A0295055F2A029A039C019F37049108 | same | ok |
| **8E CVM** | **0000000000000000020542035E031F02** | 000000000000000041031F00 | ❌ **WRONG** |
| **9F07 VSDC (contact)** | **FF80** | FF80 (fixed 2026-08-16) | ✅ fixed |
| **9F07 qVSDC (cless)** | **C080** | n/a — no cless record set | ⚠️ see note |
| 9F08 | 00A0 | same | ok |
| 9F0D / 9F0E / 9F0F | B8609C8800 / 0010000000 / B8689C9800 | same | ok |
| **9F10 IAD** | **06011203000000 → DKI 01, CVN 0x12 = CVN 18** | 06010A030000000F04 → **CVN 0x0A = 10** | ❌ **WRONG** |
| 9F38 PDOL | 9F66049F02069F03069F1A0295055F2A029A039C019F3704 | same | ok |
| 9F49 / 9F4A | 9F3704 / 82 | same | ok |
| 9F51 / 9F52 / 9F56 | 0368 / 830800000000 / 80 | same | ok |
| 9F5A Program ID | 6003680368 | absent | ❌ missing (qVSDC) |
| 9F68 Card Addl Processes | 0080D000 | absent | ❌ missing (qVSDC) |
| 9F69 Card Auth Rel. Data | 01000000000000 | absent | ❌ missing (qVSDC) |
| 9F6C CTQ | 0000 | absent | ❌ missing (qVSDC) |
| 9F6E Form Factor Ind. | 40700700 | absent | ❌ missing (qVSDC) |
| 9F7D App Code Level | 3230303432302056534443204346473130203239322030303031 | absent | ❌ missing |
| DF21/DF31 (BF56) CTCL/CTCUL | 00 / 00 | absent | ❌ missing |
| DF01 (BF5B) App Capabilities | 0000 | absent | ❌ missing |

### ❌ 8E — CVM list is wrong, and this is why the card asks for NO PIN
Profile value `0000000000000000 0205 4203 5E03 1F02` decodes exactly to the profile's declared
`contactcvms=[Online PIN, Signature, No CVM Required]`:
- `02 05` enciphered PIN verified **online**, if purchase with cashback
- `42 03` enciphered PIN verified **online**, if terminal supports the CVM (b7 = fall through)
- `5E 03` **signature** (CVM 0x1E), if terminal supports the CVM (b7 = fall through)
- `1F 02` **No CVM**, if not unattended/manual cash and not cashback
The July 2026-07-24 change replaced this with `41 03 1F 00` = offline **plaintext** PIN then No-CVM.
That was wrong twice over: it was made to fix a decline it never caused (the real cause was the AUC
— see [[visa-pos-groundtruth]]), and it deviates from the approved profile. This terminal does not
support offline plaintext PIN, so rule `41 03` is skipped and No-CVM applies (live proof:
`9F34 = 3F0001`). **Restore the profile value verbatim — do not invent a list.**

### ❌ 9F10 — we personalize CVN 10, the profile mandates CVN 18
Profile and manual both give `9F10 = 06011203000000`: length 06, DKI 01, **CVN 0x12 (18)**,
CVR 03000000. The manual's dual-interface example is explicitly labelled "VSDC CVN18, qVSDC CVN18".
Our engine writes `06010A030000000F04` (`orchestrator.cpp` DGI 9200) = **CVN 0x0A (10)**, plus two
stray bytes beyond the declared length of 6. The live card confirmed it: the GENERATE AC IAD came
back `06 01 0A 03 A090000F04` → CVN 10.
**Why this matters:** the CVN tells the issuer host HOW to rebuild the cryptogram. CVN 18 and CVN 10
use different input data, so a host provisioned for this product (CVN 18) cannot validate a CVN 10
ARQC even with the correct IMK-AC. This is a prime suspect for the online leg failing, and it is
fixed in perso, not at the host. Fix before asking the issuer to re-test ARQC validation.

### ⚠️ 9F07 is INTERFACE-SPECIFIC — do not "unify" it
The profile carries **two** 9F07 values: `FF80` for VSDC (contact) and `C080` for qVSDC
(contactless). The original bug was the engine writing the **contactless** value (C080) into the
**contact** record, which declined every POS purchase. The 2026-08-16 fix set the contact record to
FF80 — correct. When the contactless record set is built, it must carry **C080**, not FF80. The
engine's `VisaPersoConfig::auc` is currently a single value feeding the one (contact) 9F07; a
contactless record set will need its own.

## Contactless (qVSDC) — why tap fails, and the vendor's exact recipe
Our cards have **no PPSE**, so the contactless kernel cannot discover the application at all
(`SELECT 2PAY.SYS.DDF01` → 6A82 → `emvAppBuildList -4106`). The manual is unambiguous:
"1 PPSE application : 325041592E5359532E4444463031 (**mandatory for contactless**)".

**PPSE/PSE are separate instances of the VSDC 2.9.2 applet**, from the StubServer package:
```
StubServer_xxxxxx.cap   Package AID A00000000316
                        Applet AID 1 A0000000031650   <- used to install PSE and/or PPSE
                        Applet AID 2 A0000000031644
Load order: 1) StubServer_xxxxxx.cap   2) VSDC_292_xxxxxx.cap
Delete instances in the INVERSE order of creation.
```
Exact INSTALL [for install and make selectable] from the manual (both return 9000):
```
PSE : 80E60C0024 06 A00000000316 07 A0000000031650 0E 315041592E5359532E4444463031 0100 02 C900 00
PPSE: 80E60C0024 06 A00000000316 07 A0000000031650 0E 325041592E5359532E4444463031 0100 02 C900 00
      (load file / module / instance AID / priv 00 / params C900 / no token)
```
Then personalize:
```
PPSE  DGI 9102 (FCI): A5 > BF0C > 61 > { 4F <AID>, 50 <label>, 87 <priority>, 9F2A <kernel id 03> }
PSE   DGI 9102 (FCI): A5 > { 88 <EF_DIR SFI 01>, 5F2D <lang>, 9F11 <code table 01> }
PSE   DGI 0101 (SFI1 rec1): 70 > 61 > { 4F, 50, 9F12, 87 }
```
**Note a related defect this exposes:** our engine writes that PSE-style `70 > 61 > {4F,50,9F12,87}`
directory record as DGI 0101 **inside the payment applet** (SFI 1 rec 1), and the AFL points at it.
Per the manual that record belongs to the **PSE instance**, not the Debit/Credit instance. It is why
our card's SFI 1 rec 1 holds a directory entry instead of application data.

Beyond discovery, the qVSDC GPO answers must carry real data. The manual's 9115/9116/9117 each hold
`82, 94, 57, 5F20, 5F34, 9F10, 9F26, 9F27, 9F36, 9F5D, 9F6C, 9F6E` — our engine emits only
`82 + 94`. So even with a PPSE the contactless transaction would not complete.

**Scope of the contactless work (NOT a one-liner):**
1. Confirm the **StubServer package A00000000316 is loaded** on the card (`card-analyze` GET STATUS).
   If absent it must be loaded before any PPSE instance can be installed.
2. INSTALL the PPSE instance (and optionally PSE) per the APDUs above.
3. Personalize DGI 9102 for the PPSE (and 9102 + 0101 for the PSE).
4. Fill out qVSDC DGIs 9115/9116/9117 with the full element set, using **9F07 = C080** and the
   qVSDC-side profile values (9F5A, 9F68, 9F69, 9F6C, 9F6E).
5. Move the 61-directory record out of the payment applet's SFI 1 rec 1.

## Caveat on the manual's record layout
The manual's §6.1 dual-interface example is explicitly "not a real profile to be issued in the
field" and its record/AFL layout (0101 = track2/name, 0201-0206 = ODA chain) differs from ours,
which was derived from the VPA profile + live trace (see deliverable
`2026-07-20-visa-vsdc-record-afl-layout.md`). Use the manual for **mechanism** (how PPSE is
installed, which DGIs exist, what belongs in them); use the **VPA profile XML for values**.
Do not restructure our AFL to match the manual example.
