---
name: Test Card Inventory — Gemalto/Thales M/Chip + BIX (ground truth, 2026-07-13/14)
description: First-hand GET STATUS analysis of the physical test card in the ACS ACR39U reader — Gemalto/Thales GP JavaCard, MC card manager, VISA2-diversified SCP02, installed-but-unpersonalized M/Chip applet, BNPRS BIXAPP_K3 present. Metadata only — NO key values (KCV/labels/AIDs only, PCI).
type: project
---

> Ground truth from reading the actual card over an authenticated SCP02 session (gp.jar v25.10.20,
> Java 25). **NO key VALUES recorded** — only KCV / diversification scheme / AIDs (PCI Card Production).
> Validates the engine's locked assumptions (SCP02) and corrects an earlier mis-read (M/Chip absent).

## Card platform
- **Chip:** NXP (CPLC ICFabricator=4090), ICType=0075, OS ID 1981; **JavaCard v3**, **GlobalPlatform 2.3**.
- **Card Manager / ISD AID:** `A000000004000000` (Mastercard RID) — state **OP_READY**, full admin privileges.
- **Secure channel:** **SCP02, i=55** (confirmed from card recognition data tag 64 — independent of the Gemalto trace).

## ISD key (SCP02) — HELD (test card)
- **Master key KCV = `C277BA`** (key value = a Thales test key; VALUE NOT stored here — in-memory use only).
- **Key Version Number = 01**; 3 keys (ID 1/2/3 = S-ENC/S-MAC/S-DEK), 2TDEA/3DES, all same value.
- **Diversification = VISA2** (proven offline: VISA2-diversified session key reproduced the card cryptogram;
  raw + EMV did not). So gp auth = `--key <test> --key-kdf visa2`.
- KDD (from INIT UPDATE) is CPLC-based (fab date/serial/batch). Earlier "default GP 40..4F" was correctly ruled out.

## Applets (instantiated) — from authenticated GET STATUS
| AID | Identity | SELECT (unpersonalized) |
|---|---|---|
| `A0000000180F0000018330324444` | **M/Chip payment applet** (Gemalto-RID instance) — confirmed by Gemalto | **6999** (installed, not perso'd) |
| `A000000018020001656D7661706900` | Gemalto `emvapi` (EMV toolkit) | 6999 |
| `A000000018320A0200…` | Gemalto 32-series applet | 6999 |
| `A0000000180F0000018304` | Gemalto `0F04` utility applet | 9000 (selects) |
| `A0000003764249584150505F4B33` | **`BIXAPP_K3`** — BNPRS BIX applet | 9000 (selects) |

Packages (~15 LOADED): JavaCard framework (Sun `A000000062…`), Gemalto libs (`A000000018…`, incl. emvapi
pkg v3.1/v1.0), GlobalPlatform SSD + CASD (`A000000151…`), Visa/GP (`A000000003…`/`A000000030…`).

## Second UAT card — VISA (same batch, SAME ATR, 2026-07-14)
The two UAT cards share the identical ATR `3BFE13…` (same Gemalto chip/OS/mask) — distinguish them by the
**Card Manager RID**, not the ATR:
- **ISD / Card Manager: `A000000003000000` (Visa RID)** — vs the MC card's `A000000004000000` (MC RID).
- Same UAT ISD key authenticates (`C277BA`, VISA2, KVN01) — same test batch.
- **Visa payment applet (instance): `A000000018320A020000000000000000`** — state **`6999`** (installed,
  UNPERSONALIZED). This is the Visa analogue of the MC card's M/Chip instance.
- Also present: Gemalto `emvapi` (`A0000000180200…`, 6999), **BIXAPP_K3** (`A0000003764249584150505F4B33`,
  selectable 9000). Visa payment packages `A00000000310` / `A00000000316` LOADED.
- Standard AID `A0000000031010` / `A0000000031056` NOT directly selectable (6A82) — same placeholder pattern.
- => Same perso path + same INSTALL-based entry (INSTALL under `A0000000031010` from pkg `A00000000310`).

## Key findings / corrections
1. **The M/Chip payment applet IS installed** — under the **Gemalto-RID instance AID** `A000000018 0F…`,
   NOT the standard MC AID `A0000000041010`. That is why an earlier `SELECT A0000000041010` returned 6A82
   and I wrongly concluded "no M/Chip applet." It is present, just **unpersonalized**.
2. **`6999` = `SW_APPLET_SELECT_FAILED`** = EXPECTED for an installed-but-unpersonalized EMV applet
   (JCRE rejects select() until perso'd). Gemalto confirmed: not a config/install issue — personalize then re-test.
3. Card is delivered **pre-loaded + pre-installed** with the applet → **no CAP load / INSTALL needed**;
   only **data personalization** (open SCP02 → SELECT instance → STORE DATA the DGIs).
4. **`BIXAPP_K3` (BNPRS BIX applet) is already on the card** and selectable.

## AID-after-perso question (open; confirm with Gemalto)
Personalization does **not** rename the GP registry instance AID — it stays `A000000018 0F…` (6999→9000 after
perso). Whether a terminal can `SELECT A0000000041010` depends on **install-time** config + the **PPSE**
(tag 4F ADF Name), NOT on STORE DATA. PPSE currently 6A82 (not built). Ask Gemalto: under which AID does a
terminal select post-perso, and is the PPSE populated during perso? Verify empirically after first perso.

## Dependency status implied
- **SCP02 transport key:** ✅ HELD (KCV C277BA, VISA2, KVN01) — we can open the channel to the card now.
- **M/Chip data keys** (UDK via IMK-AC/SMI/SMC, CVV via CVK, PIN): ❌ still from bureau (na-003/007 grc-kms).
- **STORE DATA emitter:** engine P4/P5 unbuilt, BUT **gp.jar can drive STORE DATA** over the channel — a first
  perso can sidestep the unbuilt engine once the DGI data + card keys are available.

## Repro
`gp.jar --key <thales-test-key> --key-kdf visa2 --list` (Java 25). INIT UPDATE alone (opensc-tool) is safe
and never increments the auth-fail counter; card-cryptogram verification precedes EXTERNAL AUTHENTICATE, so a
wrong key/scheme aborts before any failed auth reaches the card.

See also: [[perso-resources-inventory]] (SCP02 from trace), [[emv-engine-architecture]] (engine seams).
