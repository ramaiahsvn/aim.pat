# Visa applet instantiation report — for Gemalto/Thales

**From:** BNPRS / ITPartners — BRUID personalization team
**Date:** 2026-07-09
**Card:** Gemalto GP JavaCard (test sample) · **ISD `A000000003000000`** (Visa-RID) · OP_READY
**Reader:** ACS ACR39U ICC Reader (PC/SC, contact)
**ATR:** `3BFE130000100080318066B0840C016E0183009000`
**Access:** authenticated `GET STATUS` / `INSTALL` over an **SCP02** session (VISA2-diversified ISD keys, KVN 01)

> Unpersonalized test card — no cardholder data (no PAN/PIN/track) and no key values appear in this report.
> This card is a **different sample** from the MC-RID card in the M/Chip report; here the Visa payment
> module was pre-loaded, so we were able to **instantiate the Visa applet successfully** (§3).

---

## 1. Purpose

Record and confirm the successful **`INSTALL [for install]`** of the Visa payment applet from the
pre-loaded Visa package, and confirm the install parameters + next personalization steps.

---

## 2. Relevant loaded packages (Visa payment)

| Package | Modules (applet AIDs) |
|---------|-----------------------|
| `A00000000310` v1.0 | `A0000000031056`, `A000000003104D` |
| `A00000000316` v1.0 | `A0000000031644`, `A0000000031650` |
| `A0000000030000`, `A00000003080000000093100`, `A000000030800000000A1500`, `…0A4800` | Visa/GP infrastructure |

Common to this card (as on the MC sample): Gemalto EMVAPI + system packages, GlobalPlatform, Oracle
JavaCard framework, and BNPRS `BIXAPP_K3` (`A0000003764249584150505F4B33`).

---

## 3. Instantiation — operation & results

### 3.1 Before install — target AID not registered
```
SELECT A0000000031010  -> 6A 82   (Visa credit/debit AID, not present)
SELECT A0000000031056  -> 6A 82   (module AID — not directly selectable)
SELECT A000000003104D  -> 6A 82
SELECT A0000000031644  -> 6A 82
SELECT A0000000031650  -> 6A 82
```

### 3.2 INSTALL [for install]  (over SCP02)
```
Package (load file) AID : A00000000310
Executable module AID   : A0000000031056
Instance AID (created)  : A0000000031010     (standard Visa credit/debit)
Result                  : SUCCESS
```
> Byte-level `INSTALL [for install]` C-APDU/R-APDU (SCP02-wrapped) available on request via a
> `--debug` re-run (delete + re-create) when this card is reinserted.

### 3.3 After install — instance is live and selectable
```
GET STATUS:  APP: A0000000031010 (SELECTABLE)      (was absent before)
SELECT A0000000031010  -> 90 00 + FCI               (was 6A82 before)
```

---

## 4. Our reading, and what we need from you

**Our reading:** the Visa payment applet lives in package `A00000000310` as module `A0000000031056`
and instantiates cleanly to the standard Visa AID `A0000000031010`. The instance is **bare /
unpersonalized** — no PAN, keys, or tracks yet.

**Please confirm:**
1. The correct **module → instance** mapping for production (is `A0000000031056 → A0000000031010`
   the intended Visa credit/debit path, and what are `A000000003104D` / the `A00000000316` modules for?).
2. The required **`INSTALL [for install]` parameters** (application privileges + install `C9` data) for
   the production Visa instance — we used defaults for this test.
3. That our held **Visa VPA profile** (DGI/tag layout) is the current perso profile for this applet
   version, and any `STORE DATA` sequencing notes.
4. Applet **product/version** for package `A00000000310` v1.0.

**Attachment:** raw SELECT trace log (and, on request, the byte-level INSTALL trace).
