---
name: Perso Engine Handoff — bruid-iperso (instant / public-kiosk perso)
description: Implementation handoff from rnd-cperso (na-100/003, planner) to bruid-iperso. Covers the instant-issuance split model — central DataPrep + HSM produce APDU scripts, executed remotely at an untrusted public kiosk with remote supervisor auth.
type: project
---

> **Source:** rnd-cperso (na-100/003) — perso R&D/planning agent (research of record). bruid-iperso
> OWNS production implementation of the INSTANT/kiosk perso path. Delivered 2026-07-04.
>
> **Canonical design** (in rnd-cperso memory `…/003-rnd-cperso/08-memory/long-term/thales/`):
> `emv-engine-architecture.md`, `perso-resources-inventory.md`, `hsm-integration-analysis.md`.

## Instant perso — the split model (user definition, 2026-07-04)
- **DataPrep happens CENTRALLY**, where the **HSM is available** — key derivation, PIN/CVV, and the
  final **APDU perso SCRIPTS** are generated in a trusted central environment.
- Those scripts are then **sent REMOTELY to a KIOSK machine that is OPEN TO THE PUBLIC**. Any customer
  walks up to the kiosk and **gets their card issued instantly**.
- **The kiosk is UNTRUSTED — NO HSM at the kiosk.** It only executes pre-generated APDU scripts and
  performs **remote supervisor authentication** to `kms.bnprs.ai` (mTLS fleet cert, 60s window).

This is the key architectural difference from bruid-cperso (009), which runs the full engine + local
HSM inside the bureau. Here the engine is **split across a trust boundary**.

## Where the code lives
**`bpr.cpp/src/BprCardEmv`** (production C++; `github.com/ramaiahsvn/bpr.cpp`, ramaiahsvn token).
Shared engine core; iperso adds the script-generation (central) + kiosk-executor (edge) split.

## What iperso owns

### Central side (trusted, HSM present) — APDU script generation
- Reuse the shared engine (dprep's tlv/profile/embossing + `IHsmClient`; the `gp::SecureChannel` SCP02
  and `perso::Sequencer` from the design) to **emit a serialized APDU script** for one card rather than
  transmitting live to a reader. Consumes dprep's **52-field instant hex**.
- Script must be **self-contained and single-use**: pre-computed SCP02 wrapping / STORE DATA blocks so
  the kiosk needs no key material. Bind to the specific card (challenge/serial) to prevent replay.
- **PCI:** SAD (PIN block, track, CVV) handling stays central; the kiosk sees only what it must transmit.

### Edge side (untrusted public kiosk) — script executor
- `ICardChannel` (PC/SC via BprPcSc) executor that replays the APDU script to the inserted card.
- **Remote supervisor auth** (existing flow): GET CHALLENGE from card → `kms.bnprs.ai`
  (`SupervisorAuthentication`, mTLS `k3_fleet_pfx` fleet cert, **60s timeout**) → VERIFY AUTH.
- Re-perso path: `GetInsertOrUpdateData_Pat` (update vs insert). LOCK on new card. Read-back verify.
- Android POS variants (Sunmi / PAX / Feitian / Nexgo / Ciontek / Wizar / Futronic) — one executor,
  platform PC/SC backends.

### Threat model to design against (public kiosk)
- No secrets at rest on the kiosk; scripts single-use + card-bound; supervisor auth gates every issuance;
  tamper/al­tered-script detection; fail closed on network loss within the 60s window.

## Inputs / dependencies
- **bruid-dprep (008):** 52-field instant hex + `IHsmClient` (central) crypto seam.
- **bruid-cperso (009):** shares the `gp`/`sequencer` engine core (central variant).
- **na-003 KMS / kms.bnprs.ai:** remote supervisor auth endpoint + fleet certs.

See `02-cell-body/planning/todo/task-001-perso-engine-impl.yaml`.
