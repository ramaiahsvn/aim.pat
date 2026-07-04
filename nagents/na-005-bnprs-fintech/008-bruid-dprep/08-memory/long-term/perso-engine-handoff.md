---
name: Perso Engine Handoff — bruid-dprep (data prep + HSM planner)
description: Implementation handoff from rnd-cperso (na-100/003, planner) to bruid-dprep. Covers the C++ perso-engine modules dprep owns (tlv/profile/embossing) and the HSM/crypto planner (UDK/KCV/PIN/CVV/SCP02 session keys). Grounded in verified P1/P2 prototype.
type: project
---

> **Source of this handoff:** rnd-cperso (na-100/003) — the perso R&D/planning agent. That agent
> holds the *canonical design* and stays the research of record. bruid-dprep OWNS the production
> implementation of the modules below. Delivered 2026-07-04.
>
> **Canonical design docs** (in rnd-cperso's memory —
> `aim.pat/nagents/na-100-gne-esrever/003-rnd-cperso/08-memory/long-term/thales/`):
> - `emv-engine-architecture.md` — full C++ architecture (8 modules, 2 HW seams, SCP02 sequencer)
> - `perso-resources-inventory.md` — the ground-truth inputs (MC+Visa profiles, embossing spec, APDU traces)
> - `hsm-integration-analysis.md` — Operas/HSM comms + Calypso key hierarchy (labels only)
> - `reverse-engineering.md` — Ghidra RE of the Thales tooling

## Where the code lives

**`bpr.cpp/src/BprCardEmv`** (production C++ tree; remote `github.com/ramaiahsvn/bpr.cpp`, ramaiahsvn token).
A verified prototype of P1+P2 (below) is being relocated there from `trp1002.cperso.thales/persoengine`.
Integrate it into bpr.cpp conventions (`bpr_*_src.cmake`, `BprLicense`, `BprCrypt`, `BprPcSc`).

## What dprep owns (engine phases P1, P2, P3)

### P1 — `emv::tlv` + `perso::profile`  (prototype DONE, verified)
- `emv::tlv`: BER-TLV tag/length encode, DGI encoder (short + extended length), BER-TLV parser, hex helpers.
- `perso::profile`: `CardProfile` model + `VisaVpaLoader` (`<config>/template/tagelement`, reads `dgi=`)
  + `McAddonsLoader` (`<ADDONS>/WORKSHEET/ELEM`) + `group_by_dgi`.
- **PCI guardrail (enforced):** loaders reject any profile carrying a key VALUE — key slots are LABELS only.
- Verified: both real issuer profiles parse — Visa AID `A0000000031010` (32 tags, DGIs 9115+9117),
  Mastercard AID `A0000000041010` (124 tags, 8 key labels). 13 unit vectors pass.

### P2 — `perso::embossing`  (prototype DONE, verified)
- Clean-room port of the AUTHORITATIVE field map, which is dprep's own C# parser in
  `trp1002.cperso.mces2/BprDataPrep/DataPrep/EmbossingRecord.cs` + `EmbossingFileParser.cs`
  (spec V3.0 == that parser). 75 fields, 1-based, last field `PersoCardId` @21149 len8 → ends **21156**.
- CardType (field 5) values `MC`/`QI`/`PR`(=PURE). **LinkId (field 50, pos 1032 len 36)** = co-badge key.
- Production `*_Enriched_*` files are 21228 chars, single-byte, no BOM, LF-delimited; the 72-char tail
  (21157–21228) is a reserved enrichment trailer — **parse 1..21156, ignore the tail**.
- `group_by_link_id` groups co-badge MC/PURE/QI by shared LinkId. Verified on the real 3-record sample:
  0 warnings, 1 co-badge triplet (MC+PR+QI) under LinkId `910201929`. 8 unit vectors pass.

### P3 — HSM / crypto planner  (dprep OWNS this — "maintain HSM planner part in dprep")
The `hsm::IHsmClient` seam and the crypto that data prep drives. **Plan first, then implement.**
Interface (from architecture §4.4):
```
derive_udk(imkLabel, pan, psn)        // EMV Option A UDK derivation (3DES)
encrypt_under_kek(kekLabel, clearKey) // key block export
kcv(key)                              // 3-byte KCV (encrypt zeros, take 3)
mac_scp02(sessionMac, data)           // SCP02 C-MAC
gen_icc_rsa(bits) / sign_sda / gen_icc_cert  // offline data auth (SDA/DDA)
```
- Backend decision (locked): **SoftHSM2 via PKCS#11** for dev/test behind `IHsmClient`; real HSM (BprHsm
  FM/HOST/HostJNI, or the Operas KMS `kmsapipc.dll @172.17.0.11:3500`) swaps in behind the same seam.
- **Keys by LABEL only — never key values in code/files (PCI).** Maps 1:1 onto the Operas macros in
  `hsm-integration-analysis.md` (`BatchDerivation`, `ExportDESKey`, `CalculateKCV`, `TranslateDESKeyBlock`).
- dprep already owns PIN transport keys + CVV/PVV keys via **na-003/007-bnprs-grc-kms** — wire those here.
- **OUTSTANDING (blocks realistic vectors, not the design):** issuer test keys / KCVs (was rnd-cperso
  task-001.3). Algorithm correctness can be proven now with public KATs (FIPS DES/3DES, EMV Book 2 UDK,
  GP SCP02); realistic end-to-end vectors need the issuer test keys.

## Consumers of dprep output
- **bruid-cperso (009)** — central 74-field perso blob → in-bureau batch perso.
- **bruid-iperso (010)** — instant 52-field hex → central script-gen → public kiosk execution.

See `02-cell-body/planning/todo/task-001-perso-engine-impl.yaml` for the task breakdown.
