# How to obtain the Issuer RSA key for ICC certificate (9F46) signing

> rnd-cperso (na-100/003) — perso R&D/planner. 2026-07-15. Answers: "the issuer RSA key is not in KMS —
> do we contact the perso bureau or the issuer? what's the process?" Feeds task-004.1 and the cperso
> engine's last remaining crypto gate (real 9F46 ICC certs). Engine side is done — see bruid-cperso
> knowledge.yaml mem-017; only this issuer key + the BprPcSc macOS transmit fix remain.

## Why it is NOT in grc-kms

grc-kms (na-003/007) holds the **symmetric bureau keys** — ISD/SCP02 (KVN01, C277BA, VISA2) and the IMKs
(AC/SMI/SMC, 82E136). The issuer RSA key is **asymmetric issuer PKI** — a different key-management domain.
The private half is the issuer's crown jewel (mints cards that pass offline auth): it lives in an HSM and is
**never exported in the clear**. That is why it is not sitting alongside the IMKs in grc-kms.

## The 3-tier EMV PKI (who signs what)

1. **Mastercard CA** — root key; its public key (CAPK, selected by tag `8F`) is preloaded in every terminal.
2. **Issuer** — generates its own RSA keypair in an HSM, sends the PUBLIC key to Mastercard's CA, gets back
   the **Issuer PK Certificate (tag `90`)** signed by the CA. One-time per BIN/key.
3. **ICC (per card, at perso)** — generate the ICC keypair, sign the ICC PK cert (`9F46`) with the **issuer
   PRIVATE key** via an HSM call. The issuer private key never leaves the HSM.

## Where the issuer private key already is

The **perso bureau (MENTA / Thales) already holds it.** The Operas trace we decoded IS their live perso — it
wrote real `9F46` certs, so a real issuer private key signed them, and we already captured its matching
**Issuer PK Certificate as config DGI 0404** (tag 90, public). The private counterpart exists in the bureau
HSM today. (This is also why 0404 / 8F(=EF) / 9F32(=03) are fixed issuer constants in our config table.)

## The process depends on WHERE perso runs

- **Option A — perso stays at the bureau (MENTA/Thales):** we never touch the private key. The bureau HSM
  signs `9F46`; our engine hands off ICC-cert signing to them (or they run the whole perso). Matches how the
  trace was produced. Simplest.
- **Option B — perso runs in OUR HSM** (engine IHsmClient -> real HSM): the issuer private key is transferred
  **HSM -> HSM, encrypted** (under a shared KEK/ZMK, or via a key-ceremony cryptogram — never in clear).
  Arrange with the **bureau** (they generated/hold it), not the bank directly.

## Who to contact + what to ask

**Contact the perso bureau (MENTA / Thales) FIRST.** Ask:
1. Will ICC-cert (`9F46`) signing be **bureau-side**, or do we **provision the issuer key into our HSM**?
2. Issuer key metadata (non-secret): **CA PK index** (`8F`, saw EF), issuer **key index**, **modulus length**,
   **exponent** (`9F32=03`), **KCV/label**, **expiry**, and the **Issuer PK Cert (tag 90)** — we already hold
   the last one as DGI 0404.
3. For **UAT**: which **test issuer key** + **test CAPK** they used, and whether they will load the test
   issuer key into our HSM.

The **issuer (bank)** is only in the loop for the one-time **CA registration** (submitting the issuer public
key to Mastercard) — almost certainly already done for this BIN. We do NOT get the key value from them.

## UAT shortcut — proceed NOW with no external dependency

For bring-up we do not need the real key: Mastercard publishes **test CAPKs**, and we can use a
**self-generated test issuer key** — the engine's `perso::oda` module already generates one and signs
`9F46` end-to-end. Catch: cards signed with a self-generated issuer key won't verify against the bureau's
`0404` / real CAPK chain, so we also **regenerate 0404** (re-certify the test issuer public key under the
Mastercard TEST CA). Result: a fully self-consistent, terminal-verifiable UAT card, no production issuer
material touched. (For a card that must chain to the REAL 0404 we captured, we need the REAL issuer key -> the
bureau, per above.)

## ALSO ask the bureau: the secret-loading key-block format (added 2026-07-15)

The first live perso (perso-live --commit) proved the whole framework works — auth, applet INSTALL, applet
SCP02, and **31/41 DGIs accepted incl. the RSA certificates**. The **only functional gap left** is the 9
encrypted key-loading DGIs (8000/8001, 8010 PIN, 8203-8205 ICC-key CRT, A006/A016 IDN, 9000 KCVs), all → 6A80.
We DECODED the format from the trace (symmetric key DGI = 16-byte 3DES-ECB DEK-encrypted key, no KCV in the
DGI — matches our engine) and RULED OUT the DEK choice live (both session + static DEK → 6A80). The applet
loads keys via the Thales KMS `stdCPSEmvGeGKOSConfForSecretLoading` (a black box). So ask the bureau for:
- The **M/Chip Advance CPS "confidential DGI" / GeneralOS secret-loading spec** — the exact key-block format
  the applet expects (DEK derivation for secret loading, any per-block header, and whether an "initialize
  secret loading" command precedes the encrypted DGIs).
- The **PIN/KEY encryption KEK** setup (trace: `G0E01.TEST.PINENC.KEK.01`, `…KEYENC.KEK.01`) if key loading is
  done our side.
- Also the **SFI-14 (0E01) record definition** for the profile "Mastercard_DI_GFCX9_MChipAdvance Without
  IDS & SDS & CVC3".
This is the SAME conversation as the issuer-RSA-key ask (Option A: the bureau does key loading + 9F46 signing;
Option B: they give us the formats/keys to do it in our HSM).

## ALSO ask for VISA (added 2026-07-15 after the live Visa test)

The same UAT card also runs Visa (VSDC package loaded; same ISD key authenticates). A live attempt installed a
Visa instance (`A0000000031010`, params `C900`) and **5/5 inferred plaintext DGIs were accepted** — built
straight from the Visa VPA profile with the standard EMV record layout (no trace/proprietary config needed).
To complete a Visa card we still need, from the bureau:
- The **Visa VIS / VCPS Card Personalization specification** — the authoritative DGI/SFI-record layout + AFL
  (our record grouping is currently a guess) and the Visa key-loading (secret-loading) format.
- The **Visa UAT issuer master keys (IMKs)** — none are in our keystore (only the MC IMKs); needed to derive
  the Visa card keys. Labels/KCVs only (PCI).
So the request now covers BOTH schemes: M/Chip Advance (Perso Manual + secret-loading) and Visa (VIS/VCPS spec
+ Visa IMKs), plus the issuer RSA key.

## Decision needed (from the user / business)

- Central perso topology: **bureau signs (Option A)** vs **our HSM signs (Option B)**? This is the fork that
  determines whether we ever need the issuer private key locally.
- UAT: accept the **test-CA path** (self-issuer key + regenerated 0404, buildable today), or wait for the
  bureau to provision the real test issuer key into our HSM.
