# Card content report & M/Chip applet query — for Gemalto/Thales

**From:** BNPRS / ITPartners — BRUID personalization team
**Date:** 2026-07-09
**Card:** Gemalto GP JavaCard (test sample) · **ISD `A000000004000000`** (MC-RID) · OP_READY
**Reader:** ACS ACR39U ICC Reader (PC/SC, contact)
**ATR:** `3BFE130000100080318066B0840C016E0183009000`
**Access:** authenticated `GET STATUS` over an **SCP02** session (VISA2-diversified ISD keys, KVN 01)

> This is an **unpersonalized test card** — no cardholder data (no PAN/PIN/track) and no key values appear in this report.

---

## 1. Purpose of this report

Your team advised the **Mastercard (M/Chip) applet is already present** on this card. From the host side we can **confirm applet code in the Gemalto namespace**, but we cannot see anything under the standard Mastercard AID `A0000000041010`. Before we personalize, please **confirm the exact M/Chip applet identity and perso profile** (details in §4).

---

## 2. Full card inventory (`GET STATUS`)

### Selectable applet instances (5)
| # | AID | Our identification |
|---|-----|--------------------|
| 1 | `A000000018020001656D7661706900` | Gemalto EMVAPI (`"emvapi"`) |
| 2 | `A0000000180F0000018330324444` | **M/Chip candidate** (see traces) |
| 3 | `A000000018320A020000000000000000` | Gemalto proprietary |
| 4 | `A0000000180F0000018304` | Gemalto payment-family |
| 5 | `A0000003764249584150505F4B33` | BNPRS `BIXAPP_K3` |

### Loaded packages / executable modules (of interest)
| Package | Modules (applet AIDs) |
|---------|-----------------------|
| `A0000000180F000001833032` v1.0 | `A0000000180F0000018303`, `A000000018000075610717040001`, `A0000000180F0000018304` |
| `A0000000180F00000183303244` v1.0 | `A0000000180F0000018330324444` |
| `A000000018320A0100000000000000FF` v1.0 | `A000000018320A010000000000000000`, `A000000018000075D60318010019` |
| `A000000018320A0200000000000000FF` v1.0 | `A000000018320A020000000000000000` |
| `A00000001830070100000000000001FF` v1.1 | `A00000001830070100000000000001` |
| `A00000003080000000093100` v2.0 · `A000000030800000000A1500` · `…0A4800` · `A0000000030000` | Visa/GP infrastructure |
| `A00000015100`, `A0000001515350` (→ `A000000151535041`) | GlobalPlatform |
| `A0000000620001/0002/0101/0102/0201/0203/0205/0209` | Oracle JavaCard framework |
| `A000000376424958415050` (→ `A0000003764249584150505F4B33`) | BNPRS BIXAPP |

> Note: there is **no package or module under the Mastercard RID `A00000000410*`** and none under the Visa RID `A00000000310*` on this card.

---

## 3. SELECT APDU traces

```
[candidate M/Chip #1]
C-APDU: 00 A4 04 00 0E A0 00 00 00 18 0F 00 00 01 83 30 32 44 44 00
R-APDU: 69 99                         (applet-selection-failed — consistent across runs)

[candidate M/Chip #2]
C-APDU: 00 A4 04 00 0B A0 00 00 00 18 0F 00 00 01 83 04 00
R-APDU: 90 00                         (selects; empty FCI)

[standard MC AID — control, x2 fresh connects]
C-APDU: 00 A4 04 00 07 A0 00 00 00 04 10 10 00
R-APDU: 6A 82                         (not found — not registered under the MC AID)

[nonexistent AID — baseline]
C-APDU: 00 A4 04 00 07 A0 00 00 00 99 99 99 00
R-APDU: 6A 82

[partial A000000004 — ISD prefix match]
C-APDU: 00 A4 04 00 05 A0 00 00 00 04 00
R-APDU: <FCI> 90 00                   (= the ISD A000000004000000)
```

---

## 4. Our reading, and what we need from you

**Our reading:** the M/Chip applet is on the card in your namespace — `A0000000180F0000018330324444` consistently returns `6999`, which we interpret as an **installed-but-unpersonalized payment applet** that refuses SELECT until perso data is loaded. The standard `A0000000041010` returning `6A82` is expected for an un-perso'd card (that select-AID is bound at personalization).

**Please confirm:**
1. **Which AID is the Mastercard M/Chip applet** — the package/module AID and the instance AID (is it `A0000000180F0000018330324444`?).
2. **The `6999` on SELECT** — is that expected pre-perso behavior, or does it indicate a lifecycle/config issue?
3. **The M/Chip perso profile** (equivalent to the Visa VPA profile we already hold) — DGI/tag layout, mandatory data groups, and the `INSTALL [for install]` parameters.
4. **After perso**, which SELECT AID the applet registers (e.g. `A0000000041010`), and any PPSE/PSE entry it publishes.
5. Applet **product/version** for `A0000000180F00000183303244` v1.0 (to match documentation).

**Attachment:** raw trace log `mc-applet-select-apdu-trace.txt`.
