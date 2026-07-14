# INPUT → na-005/008 bruid-dprep

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-13 · **Priority:** HIGH · **Status:** OPEN
**Source doc (canonical, git-ignored — Confidential/Pointman, do NOT commit the PDF):**
`/Users/bnprs/BPR/GitRepos2/TRP1002_cPerso/trp1002.cperso.thales/Resources/Vendor_Integration_Pointman_v1.3.pdf`
Prepared by MENTA FZ LLC · "Kiosk Instant Card Issuance — Pointman Integration Guide v1.3".

## Role (user, 2026-07-13)
MENTA = perso bureau (upstream). Pointman = kiosk hardware vendor. **We (BRUID) = the perso backend** —
dprep + perso-script prep for central (cperso) and instant (iperso). dprep parses the source input, then
prepares the internal perso data (the "74-field central blob" / "52-field instant hex", `task-001.3`) that
cperso/iperso turn into scripts.

## dPrep input channels — TWO formats, split by perso type (user, 2026-07-13)
| Perso type | Downstream agent | dPrep input | Loader | Status |
|---|---|---|---|---|
| **Central** | bruid-cperso (009) | **Embossing file directly** (Tri-Badge PURE V3.0 fixed-width) | `EmbossingParser` | ✅ built (P2) |
| **Instant** | bruid-iperso (010) | **This DPI** `RequestPersoRequest` (G&D data-provider v2, encrypted) | `GdDataProviderLoader` | ❌ to build |

> So the DPI below is the **INSTANT** channel only. Central perso keeps taking the plain embossing file —
> no DPI, no DEK decrypt, no signature verify. The two loaders sit behind one interface and feed the same
> internal perso-record model.

## Why this is yours
§7.3 **DPI — Card Personalisation (`RequestPersoRequest`)** is the **INBOUND wire format MENTA sends us** for
instant issuance — dprep is on the **receiving/parsing** end. The G&D `perso-entity` data the user shared
earlier is exactly the DPI **secure block** (§7.3.1) in plaintext.

## The DPI payload dprep RECEIVES + PARSES (MENTA → us, §7.3)
SOAP `RequestPersoRequest` (ns `.../data-provider/v2`, `version="2.0.0"`), containing:
- **Envelope attrs:** `issuer-name`, `originator`, `issuer-request-id`, `operation-mode` (TEST/PROD),
  `service-type="INSTANT"`.
- **job-record:** `card-program` (e.g. `MC_PAYROLL`), `destination` (kiosk id), `perso-request-type="COMPLETE"`.
- **card-record:** `card-plastic-identifier`, `card-plastic-layout-identifier`, `sequence-nr`.
- **Clear `perso-entity` fields** (non-sensitive): `CARD_HOLDER_NAME`, `CUSTOMER_IDENTIFICATION_NUMBER`,
  `CARRIER_CODE`, `embossing.EMB_BRANCH_CODE`, `MAIL_SEQUENCE_NUMBER`.
- **`xe:EncryptedData` secure block** — all sensitive embossing fields (PAN, tracks, CVV2, ICVV, OTAC,
  expiry, account, PAN seq…), see below.

## §7.3.1 — the encrypted secure block (this is the new crypto requirement)
- **Cipher:** `EncryptionMethod Algorithm="aes-256-cbc-iso2"` → **AES-256-CBC**, `iso2` padding scheme.
  > NOTE: the engine's crypto today is 3DES-centric (BprCrypt). This adds an **AES-256-CBC** requirement —
  > implement behind the same crypto seam (OpenSSL path is available in-tree).
- **Key:** `<xd:KeyName>` = a **DEK label** (sample `MENTA/DEK/DEV_DEK_02`), agreed **per environment,
  exchanged out-of-band**. It is a LABEL, not the key value — **guardrail-safe, record label only**.
  This DEK is a NEW dependency distinct from the EMV bureau keys (IMK/CVK/PVK/ISD).
- **CipherValue:** `base64( 16-byte IV || AES-256-CBC ciphertext )` — **IV is prepended**. Decrypt =
  base64-decode → first 16 bytes = IV → AES-256-CBC-decrypt the rest under the DEK. Plaintext is an XML
  `perso-entity name="secure"` element holding the embossing fields.
- **Field split:** clear = name / CIF / branch / carrier; **encrypted** = PAN, CVV2, ICVV, track1/2, OTAC,
  expiry, account, PAN-seq.

## Envelope signing (§5, §7)
The whole SOAP Body is **WS-Security RSA-SHA1 signed** (SHA-1 digest, Exclusive C14N, key by
`X509IssuerSerial`, no timestamp) with the **MENTA-issued X.509 cert**. dprep produces the signed envelope
(or hands the signing step to iperso's transport layer — coordinate).

## Still computed by dprep (needs bureau keys)
`CVV2` / `ICVV` arrive **empty** in the data and are **computed here** using **CVK-A/B** (blocked — see
`handoff-na005-008-perso-engine-bureau-keys.md`). Confirms the CVK request. No PIN in the DPI — for kiosk
instant, PIN is likely **kiosk-entered**; confirm the PIN sourcing model.

## Action items for bruid-dprep
1. **INSTANT channel:** build the **DPI `RequestPersoRequest` CONSUMER/parser** (`GdDataProviderLoader`):
   decrypt the `xe:EncryptedData` secure block (DEK, AES-256-CBC) → parse clear + secure `perso-entity` fields →
   internal perso record → the "52-field instant hex" (→ iperso). *(SOAP transport + WS-Security signature
   verification are the Part A/B team member's, not dprep — dprep receives the DPI payload and decrypts/parses.)*
2. **CENTRAL channel:** keep the existing `EmbossingParser` (Tri-Badge PURE fixed-width) → "74-field central
   blob" (→ cperso). No change; both loaders feed one internal record model.
3. Add **AES-256-CBC (iso2 padding)** to the crypto layer; handle the IV-prepended `CipherValue` (decrypt first).
4. Track the **DEK** as an out-of-band key dependency (label only) — INSTANT channel only.
5. Compute `CVV2`/`ICVV` once CVK arrives (they arrive empty in the DPI).

## Cross-refs
- Orchestration/SOAP-contract side is iperso's — see its input `2026-07-13-pointman-kiosk-integration-v1.3.md`.
- Bureau symmetric keys: `handoff-na005-008-perso-engine-bureau-keys.md`. ODA/RSA certs: rnd-cperso `task-004`.
