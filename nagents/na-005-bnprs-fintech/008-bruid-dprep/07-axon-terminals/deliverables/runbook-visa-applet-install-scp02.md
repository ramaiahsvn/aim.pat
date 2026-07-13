# Runbook — Instantiate a Visa applet on a Gemalto GP card over SCP02

> **Owner:** bruid-dprep (na-005/008) · **Domain step:** P4 channel + GP install (bruid-cperso 009 owns production)
> **Recorded:** 2026-07-09 · **Verified on:** disposable **test card**
> **PCI Card Production scope.** Key material is referenced by **label/KCV only** — never store or log clear key values.

## Purpose
Bring a GP card's **loaded-but-not-installed** Visa applet to a **selectable instance** via
`INSTALL [for install]` over an authenticated SCP02 channel. This is the pre-perso step;
it does **not** personalize the card (no PAN/keys/tracks — that is the P5 `STORE DATA` step).

## Prerequisites
| Item | Value used |
|------|-----------|
| Reader | ACS ACR39U ICC Reader (PC/SC) |
| Card | Gemalto/Thales GP JavaCard, ISD `A000000003000000` (Visa-RID), KVN 01, **SCP02** |
| Tooling | GlobalPlatformPro `gp.jar` (needs Java 11+; used Temurin 25) + OpenSC `opensc-tool` |
| Key | **KMC** — label: *THALES-DIS test KMC*, **KCV `C277BA`**, 2-key 3DES. Diversification: **VISA2**. Supplied out-of-band via env var `KMC` — NOT stored here. |

```sh
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home
JAVA=$JAVA_HOME/bin/java
GP=/path/to/gp.jar
export KMC=<16-byte KMC hex — inject at runtime, do NOT commit>   # KCV must be C277BA
```

> **Diversification note:** this card family uses **VISA2** KDF (`--key-kdf visa2`).
> Default GP key `40..4F` and the EMV KDF were both ruled out empirically.

## Steps

### 1. Confirm a card is present
```sh
opensc-tool -a          # expect ATR 3BFE130000100080318066B0840C016E0183009000
```

### 2. Inventory what is loaded (authenticated GET STATUS)
```sh
$JAVA -jar $GP --key $KMC --key-kdf visa2 --list
```
Expect the Visa payment module present as a **PKG** but not an **APP**:
- `PKG: A00000000310` → `Applet: A0000000031056`, `Applet: A000000003104D`

### 3. Confirm the target AID is not yet selectable
```sh
opensc-tool -s "00 A4 04 00 07 A0 00 00 00 03 10 10 00"   # expect 6A82 (not found)
```

### 4. Instantiate the Visa applet  ← the write step
```sh
$JAVA -jar $GP --key $KMC --key-kdf visa2 \
  --package A00000000310 \
  --applet  A0000000031056 \
  --create  A0000000031010
```
- `--package` = loaded executable load file AID
- `--applet`  = executable module AID inside it
- `--create`  = **instance AID** to register (standard Visa credit/debit `A0000000031010`)

### 5. Verify the instance is now selectable
```sh
$JAVA -jar $GP --key $KMC --key-kdf visa2 --list | grep '^APP:'
# expect a new line:  APP: A0000000031010 (SELECTABLE)

opensc-tool -s "00 A4 04 00 07 A0 00 00 00 03 10 10 00"   # expect 9000 + FCI
```

## Result (2026-07-09, test card)
- Before: `SELECT A0000000031010` → `6A82`; 3 selectable instances.
- After:  `APP: A0000000031010 (SELECTABLE)`, `SELECT` → `9000`/FCI; 4 selectable instances.
- Instance is **bare / unpersonalized**.

## Rollback
```sh
$JAVA -jar $GP --key $KMC --key-kdf visa2 --delete A0000000031010
```

## What remains (blocked)
- **P5 personalization** (`STORE DATA`: PAN, keys, tracks) — needs **EMV issuer keys / CVK-A/B / PVK** (bureau, na-003/007).
- **P3c** CVV/PVV and **P3d** byte-exact SCP02 real-vector — same key dependency.
- The KMC only covers the **ISD/SCP02** channel; it is not the EMV issuer key set.

## Safety / compliance
- Test card only; every step is reversible (`--delete`).
- SCP02 auth uses the KMC **in memory only**; do not echo it, log it, or write it to any file.
- Repeated **failed** `EXTERNAL AUTHENTICATE` can lock the ISD — only use the confirmed VISA2 KDF; do not retry a failing KDF.
