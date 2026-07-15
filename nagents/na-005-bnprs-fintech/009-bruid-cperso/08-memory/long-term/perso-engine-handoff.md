---
name: Perso Engine Handoff — bruid-cperso (central bureau perso)
description: Implementation handoff from rnd-cperso (na-100/003, planner) to bruid-cperso. Covers the central/in-bureau execution engine — card channel, GlobalPlatform SCP02, perso sequencer, audit, Calypso key path, real-HSM adapter (engine phases P4–P6).
type: project
---

> **Source:** rnd-cperso (na-100/003) — perso R&D/planning agent (research of record). bruid-cperso
> OWNS production implementation of the CENTRAL execution engine. Delivered 2026-07-04.
>
> **🏆 STATUS 2026-07-15 — 100% COMPLETE: a fully functional M/Chip Advance card is personalized end-to-end**
> (bpr.cpp `persoengine`, 94 unit tests green; commits through `70d0a36`). `perso-live --commit` on a
> factory-fresh Gemalto M/Chip Advance card now loads **ALL 41 STORE DATA DGIs → 9000** (keys, ICC RSA CRT,
> ICC+Issuer PK certificates, SFI records, product config, Reference PIN) and the card passes the full EMV
> read flow: **SELECT → GPO (AIP 3900 / AFL) → READ RECORD** returns PAN `5213720475428723` / cardholder
> `TARIQ/ZIAD` / track2 / cert chain, and **VERIFY PIN 1234 → 9000** (offline PIN works, PTC `9F17`=03).
> `perso-live --dump` gives a read-only decoded tag walk. The earlier "9/10 DGI 6A80" gaps are all resolved —
> it was NOT a bureau/spec problem:
> - **Root cause of the key-load "poison" = DGI `AD14`** (2-byte proprietary control): it corrupts the ICC CRT
>   (8202-8205 → 6700) only when sent BEFORE it. Fix: send AD14 as the **end-of-perso LAST STORE DATA**
>   (`80E280<P2>02AD14`, P1.b8=1) — loads after the keys AND transitions the applet SELECTABLE→PERSONALIZED.
> - **Ordering:** load in the trace's P2 order (NOT keys-first); keyset KCVs `9000`/`9103` computed from the
>   diversified UDKs; ICC CRT regenerated so `qInv/dq/dp` are full-length (clean size inference, no A004).
> - **PIN:** DGI `9010` = PTC(1)‖PTL(1) = **2 bytes** (§6.21); the config's 1-byte value → 6985 (fixed → `0303`).
> - **SCP02 crypto** = ISD master (KVN01) **VISA2-diversified**, verified live vs gp.jar. BprPcSc macOS transmit
>   fix merged. Only `0E01` (SFI-14 E5-vs-70 template quirk on GCX7.5) is skipped — non-essential.
> - **Finalize (issuance):** `--commit --secure` re-selects ISD and SET STATUS card→SECURED (`80F0800F00`,
>   MANDATORY per manual for a functional card; thereafter GP management needs C-MAC).
> The full recipe + decode: rnd-cperso `…/thales/mc-advance-dgi-map.md` (see the "🏆 100% COMPLETE" section);
> milestones knowledge.yaml **mem-015…mem-024**. NEXT applet: Visa (VSDC).
>
> **Canonical design** (in rnd-cperso memory `…/003-rnd-cperso/08-memory/long-term/thales/`):
> `emv-engine-architecture.md`, `perso-resources-inventory.md`, `hsm-integration-analysis.md`,
> `reverse-engineering.md`.

## Central perso (this agent's context)
Personalization happens **fully inside the perso bureau** — secure facility, **HSM on-site**,
high-volume **offline batch**. Contrast bruid-iperso (010): instant/kiosk, no HSM at point of issue.

## Where the code lives
**`bpr.cpp/src/BprCardEmv`** (production C++; `github.com/ramaiahsvn/bpr.cpp`, ramaiahsvn token).
Shared engine core. dprep (008) delivers the data + HSM crypto seam; cperso drives execution.

## What cperso owns (engine phases P4, P5, P6)

### P4 — `card::ICardChannel` + `gp::SecureChannel` (SCP02)
- PC/SC transport (`ICardChannel` → BprPcSc); auto-handle `61xx` GET RESPONSE / `6Cxx` wrong-Le.
- GlobalPlatform **SCP02** (CONFIRMED from the Gemalto trace): INITIALIZE UPDATE (host challenge) →
  28-byte response (key-div-data ∥ key-info ∥ card-challenge ∥ card-cryptogram) → verify card cryptogram
  → EXTERNAL AUTHENTICATE (host cryptogram ∥ C-MAC). Session keys derived in the HSM (dprep's seam).
- **Acceptance oracle:** trace-replay against the recorded Gemalto/TechTrex APDU sequences (a
  `MockCardChannel` asserting emitted APDUs == recorded). SCP03 slots behind the same interface later.

### P5 — `perso::Sequencer` + `audit`
Drive the exact recovered sequence (architecture §4.7), now PROVEN live end-to-end:
```
per card: connect → SELECT CM → SCP02 open (VISA2) → DELETE stale → INSTALL[for install&make selectable] →
          per applet { SELECT, SCP02 re-auth, per DGI (trace P2 order): STORE DATA (80E2 P1 P2),
                       P1=0x60 for DEK-wrapped keys / 0x00 plaintext; skip AD14+0E01 } →
          STORE DATA AD14 with P1.b8=1  ← end-of-perso, applet → PERSONALIZED (the finalize control) →
          read-back verify (GPO → AFL → READ RECORD 5A/57/5F24/8C/8D/82/94; VERIFY PIN) → audit →
          [issuance: re-SELECT CM, SCP02, SET STATUS card→SECURED 80F0800F00] }
```
- Error recovery: on any non-9000 SW → abort card, log tag context + SW, continue batch
  (configurable stop-on-error). **Never silently retry a partially-personalised card.**
- Audit: JSON-lines per card `{linkId, aid, scheme, dgiCount, result, sw?, durationMs}`;
  **no PAN/PIN/keys** (mask PAN first6+last4). Mirrors OP_MakeAudit in the old stack.
- Existing pipeline to align with: `qiscript_central_preperso` → `qiscript_applet_loading_ecebs` →
  `qiscript_central_perso(embData,74)` → LOCK (INS 0xF0) → verify. Vendor pre-perso is a runtime
  switch (`BprMces2Config.xml` CardVendor: Gemalto|Gnd|Kona).

### P6 — Calypso key path + real-HSM adapter
- Calypso/TRANSLINK key scheme (CI/TP/TV/TS/TR/TD from the existing hierarchy in
  `hsm-integration-analysis.md`) — its own derivation path behind `IHsmClient`, validated separately.
- Real-HSM adapter: swap SoftHSM2 → **BprHsm** (FM / HOST / HostJNI) or the Operas KMS
  (`kmsapipc.dll @172.17.0.11:3500`) behind the same seam. Keys never leave HSM in plaintext.

## Inputs / dependencies
- **bruid-dprep (008):** 74-field central perso blob + `IHsmClient` crypto seam.
- **bruid-applet (007):** target applet — defines the data/field format constraints.
- **STORE DATA P1=0x60 blocks:** ✅ RESOLVED — P1=0x60 = DEK-wrapped key DGIs (keys 3DES-ECB under the SCP02
  session DEK); P1=0x00 = plaintext; P1.b8=1 = last block / end-of-perso. Confirmed live against the applet.

See `02-cell-body/planning/todo/task-001-perso-engine-impl.yaml`.
