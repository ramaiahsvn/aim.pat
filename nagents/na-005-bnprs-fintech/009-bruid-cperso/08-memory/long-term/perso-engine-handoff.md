---
name: Perso Engine Handoff — bruid-cperso (central bureau perso)
description: Implementation handoff from rnd-cperso (na-100/003, planner) to bruid-cperso. Covers the central/in-bureau execution engine — card channel, GlobalPlatform SCP02, perso sequencer, audit, Calypso key path, real-HSM adapter (engine phases P4–P6).
type: project
---

> **Source:** rnd-cperso (na-100/003) — perso R&D/planning agent (research of record). bruid-cperso
> OWNS production implementation of the CENTRAL execution engine. Delivered 2026-07-04.
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
Drive the exact recovered sequence (architecture §4.7):
```
per card: connect → SELECT CM → SCP02 open → DELETE stale → INSTALL[for load&make] →
          per applet { SELECT, SCP02 re-auth, per DGI: STORE DATA (80E2 P1 P2) } →
          optional read-back verify (5A/57/5F24/8C/8D/82/94/…) → audit
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
- **STORE DATA P1=0x60 blocks:** confirm semantics (encrypted key/DGI) by decoding a few from the trace
  before finalising the GP module (architecture §8 open item).

See `02-cell-body/planning/todo/task-001-perso-engine-impl.yaml`.
