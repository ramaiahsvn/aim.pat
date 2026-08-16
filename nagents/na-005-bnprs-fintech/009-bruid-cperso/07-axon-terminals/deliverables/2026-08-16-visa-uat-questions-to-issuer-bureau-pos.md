# Visa UAT — what to ask, and WHO to ask, to clear the ODA decline

**Date:** 2026-08-16 · **Card:** our perso'd Visa, PAN 4177630226449323 (BIN 417763),
AID A0000000031010 · **Profile:** ISC Visa Debit | Online-Only (`4000048094.v1`,
Visa approval LBTHAL05289A), issuer BID 10083366 · **Terminal:** Sunmi/aeonpay, KIOSK-DXB-014.

## Where we are (so the counterparty has the picture in one paragraph)

The card now reaches the issuer online. Offline AUC decline fixed (9F07 FF80), CVM restored to the
profile list, IAD set to CVN 18 (9F10 = 06011203000000), and the ATC replay decline cleared by the
host-side ATC reset. **Current decline is 05, "Chip Data missing – TVR Bit 3" = TVR byte 1 bit 0x20
"ICC data missing."** Cause: the profile's contact AIP is 3800, which claims **DDA**, but our UAT
card carries no offline-data-authentication certificate chain (issuer cert 90 / ICC cert 9F46 / CA
index 8F). A card that advertises DDA must carry the certs, so the decline is legitimate per the
approved profile.

**Do NOT read this as "our card is broken again."** Every value we personalize now matches the VPA
profile; what is missing is a cert chain we cannot complete without external material, and the
terminal currently cannot verify one even if we shipped it.

## The one question most likely to unblock a passing transaction — ask the ISSUER HOST team

> **This is an Online-Only profile. Will your host stop declining these UAT cards on the offline
> data-authentication TVR bits (bit 3 "ICC data missing" and bit 2 "DDA failed"), and authorize on
> the online ARQC alone?**

Rationale to give them: for an online-only product the online ARQC is a stronger, dynamic
authentication than offline DDA; many online-only deployments do not gate authorization on the ODA
TVR bits. If they agree, the next re-perso should authorize with no card change and no keys — because
the ARQC path is already in place. This is the fastest route to a green test.

## Confirm the ARQC actually validated — also the ISSUER HOST team

The 05 decline is on the TVR, which the host may check **before or independently of** the cryptogram.
So we still do not know our ARQC is cryptographically good. Ask:

> **Independently of the TVR decline, did our ARQC cryptographically validate?** We personalize
> **CVN 18** (IAD 9F10 = 06011203000000, DKI 01), with our Visa IMK-AC of **KCV 944A44**. Please
> confirm your host holds a Visa IMK-AC with **KCV 944A44** at **DKI 01** and derived it for
> **CVN 18**. Share the KCV, never the key.

Why this matters: if the TVR gate is relaxed (question 1) but the ARQC does not validate, we hit the
next wall. Getting both answers now avoids spending a second card to discover a key mismatch.

## If they will NOT relax the TVR gate — then ask the PERSO BUREAU (MENTA / Thales)

Clearing the decline the conformant way means shipping a verifiable DDA cert chain. Two things are
needed and both come from the bureau:

1. **Visa VIS / VCPS Card Personalization specification** — the authoritative SFI-record / AFL layout
   and the ODA cert-chain DGI format for this applet (our SFI-3 record grouping is currently
   inferred, and DGI 0301 returns 6A88 for a reason we have not isolated).
2. **The UAT issuer key material**, one of:
   - the **test issuer RSA key + the matching test CAPK** loaded so the chain is self-consistent, OR
   - if perso runs in our HSM: the **issuer RSA key provisioned HSM→HSM** (never in clear), with its
     non-secret metadata — **CA PK index (8F), key index, modulus length, exponent (9F32=03),
     KCV/label, expiry**, and the **Issuer PK Certificate (tag 90)**.
3. **Visa UAT issuer master keys (IMKs)** — our keystore holds only the MC IMKs; we need the Visa set
   (AC/SMI/SMC) to derive card keys. **Labels/KCVs only — no key values (PCI).** (This also lets them
   confirm the KCV 944A44 above is the right master.)

Background for the bureau: see `rnd-cperso 2026-07-15-issuer-rsa-key-process.md`. Options A (bureau
signs 9F46) vs B (our HSM signs) is their call to state.

## Independently — the POS / ACQUIRER team must fix a terminal bug

This blocks the cert path regardless of keys, so raise it in parallel:

> **The terminal's CAPK loader crashes and loads NO CA keys into the kernel.** Log:
> `hexStr2Bytes StringIndexOutOfBounds length=495 index=495` (odd-length CAPK hex) in
> `CAPKsLoader.syncCAPKsToEMVKernel`. With no CAPK in the kernel the terminal cannot verify any
> certificate chain, so even a perfectly personalized DDA card would set TVR "ODA not performed."
> Please fix the loader and confirm **which Visa CA public key index(es) the terminal will hold**, so
> our card's 8F matches.

(Open since 2026-07-24; recorded in bruid-cperso knowledge.yaml.)

## Decision for us (business/topology), needed before the bureau can answer cleanly

- **Perso topology:** bureau signs the ICC cert (Option A) or our HSM signs it (Option B)? This
  decides whether we ever need the issuer private key locally.
- **UAT chain:** accept the self-generated test-issuer-key + regenerated CA chain (buildable today,
  but only works once the terminal holds the matching test CAPK), or wait for the bureau to provision
  a real test issuer key.

## One-line routing summary

| Ask | Who | Unblocks |
|---|---|---|
| Relax ODA TVR gate for online-only UAT | **Issuer host** | a passing txn, no card change (fastest) |
| Confirm ARQC validated (CVN 18 / KCV 944A44 / DKI 01) | **Issuer host** | the next wall after the TVR gate |
| Visa VIS/VCPS spec + test issuer key/CAPK + Visa IMKs (KCVs only) | **Perso bureau (MENTA/Thales)** | the conformant cert-chain path |
| Fix CAPK loader; state the CA index the terminal holds | **POS / acquirer** | terminal-side ODA verification |
