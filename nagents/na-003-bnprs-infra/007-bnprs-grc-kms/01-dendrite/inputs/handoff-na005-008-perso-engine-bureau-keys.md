# HANDOFF → na-003/007 bnprs-grc-kms

**From:** na-005/008 bruid-dprep (perso engine owner) · **Routed by:** na-100/003 rnd-cperso (planner/design of record)
**Date:** 2026-07-13 · **Priority:** HIGH (blocking live personalisation) · **Status:** OPEN

## Ask (one line)
Provide the **labels + KCVs** (never clear key VALUES — PCI Card Production) for the issuer/ISD
key set below, plus the **card-key diversification method**, so the BRUID perso engine can open a
real SCP02 secure channel and compute security values. This is the sole blocker holding perso-script
generation for a live Mastercard card (AID `A0000000041010`).

**Requesting because:** a blank MC GP JavaCard was presented for personalisation. The engine has all
crypto/data modules built and unit-verified (44/44 tests) but is **PAUSED awaiting these keys**.
Default GP keys `40..4F` are **ruled out** — the observed card key-div-data `00002060BB8D509C2020`
implies **MC-style diversification**, so the card cannot be opened without the real ISD key + method.

**Design of record (read for algorithms/derivation):**
`aim.pat/nagents/na-005-bnprs-fintech/008-bruid-dprep/08-memory/long-term/hsm-crypto-planner.md`
(§2 UDK/KCV/SCP02, §3 key inventory). Engine code: `bpr.cpp/src/BprCardEmv/persoengine`.

---

## Exact keys requested — LABELS + KCVs ONLY

> Return: for each, the **grc-kms label/alias**, **key type**, **KCV (3-byte)**, and **KVN** where
> applicable. Do **not** return clear key values. If custodied in AWS KMS / HSM, return the
> **handle/alias + KCV** only.

| # | Key(s) | Type | KVN | Purpose | Unblocks |
|---|--------|------|-----|---------|----------|
| 1 | **SCP02 ISD static** — S-ENC / S-MAC / S-DEK **+ the card-key DIVERSIFICATION METHOD** | 2TDEA | **01** | Open SCP02 secure channel to the card | `DISABLED_` SCP02 real-trace vector (`scp02_test.cpp`); real card auth |
| 2 | **IMK-AC / IMK-SMI / IMK-SMC** | 2TDEA | — | EMV Option-A UDK derivation | P3a UDK end-to-end validation |
| 3 | **CVK-A / CVK-B** | 2TDEA | — | CVV / iCVV / CVV2 | P3c |
| 4 | **PVK** | 2TDEA | — | PVV | P3c |
| 5 | **PIN-TK** (PIN transport key) | 2TDEA | — | ISO 9564-1 Format-0 PIN block | P3b confirmation vs a real encrypted PIN block |

**Most urgent = #1** (ISD KVN=01 + diversification method). Items 2–5 unblock security values but
#1 is what lets any script talk to the card at all.

### On the diversification method (item 1)
Confirm which applies and the exact input construction:
- MC-style master-key diversification (e.g. derive card ISD key from a base key + card
  serial/CSN) — the div-data `00002060BB8D509C2020` was observed on the presented card.
- Whether S-ENC/S-MAC/S-DEK are separately diversified or derived from one base key.

---

## Guardrails (both sides)
- **Labels + KCVs only.** No clear key material in any file, code, log, or reply. (PCI Card Production.)
- Cardholder data stays synthetic/test until keys + method are validated end-to-end.
- rnd-cperso (na-100/003) holds the design; bruid-dprep (na-005/008) owns the engine and is the
  return recipient for the labels/KCVs.

## Return to
Deliver the label/KCV manifest to **na-005/008 bruid-dprep** (drop into its
`01-dendrite/inputs/`) and note here when OPEN → DELIVERED. rnd-cperso will then enable the
`DISABLED_` SCP02 vector and validate P3c.
