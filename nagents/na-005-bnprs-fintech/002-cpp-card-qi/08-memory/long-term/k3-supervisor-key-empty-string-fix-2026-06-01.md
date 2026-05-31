# BprCardQi — QiVerifyChallengeK3Api "empty string" / perso 6982 — root cause & fix (2026-06-01)

## Symptom
Card perso (instant-perso-direct path) failed at the supervisor / EXTERNAL-AUTH step.
`QiVerifyChallengeK3Api` returned an empty string → empty `SUPERVISOR_KEY` was sent →
card replied **`6982`** (security status not satisfied), after which the whole session
broke and every following APDU cascaded to `6D00` / `6881`.

## Diagnosis path (kept the actual signal chain — useful next time)
1. Coordinated with **na-003/007 bnprs-grc-kms**. Proved the KMS service is HEALTHY:
   live mTLS `curl` with the fleet identity → `HTTP 200 {"response":"<16hex>"}`,
   Lambda logged the test invocations. CA/truststore/route/domain all matched.
   → so the empty string is **device-side**, not server-side.
   (See grc-kms memory: `k3-verifychallenge-health-2026-06-01.md`.)
2. KMS Lambda had **zero invocations in the prior 48h** → real perso requests never
   reached it → the HTTPS call dies on the device before leaving the machine.
3. Added `[K3]` diagnostics to `QiVerifyChallengeK3Api` (was silent on every failure):
   cert-load, each WinHTTP call + `GetLastError()`, HTTP status, body len, parse result.
4. Device log: `[K3] HTTP status=0`, then `WinHttpSendRequest sent=0 gle=12185`.
   **`12185` = ERROR_WINHTTP_CLIENT_CERT_NO_PRIVATE_KEY** — WinHTTP couldn't use the
   client cert's private key.
5. First attempt (no-persist / CNG ephemeral import) still 12185 with NO retry line →
   proved WinHTTP **re-opens the key from a NAMED key container** at send time, so an
   ephemeral key is invisible to it.
6. Switched to MACHINE keyset + added a `CryptAcquireCertificatePrivateKey` probe.
   Both MACHINE and USER reported `acquirable=0 gle=2148081675`
   (**0x8009200B = CRYPT_E_NO_KEY_PROPERTY** — that cert has no associated key).
7. Realised the probe was testing only ONE cert — whatever
   `CertFindCertificateInStore(CERT_FIND_ANY)` returned first. A PFX imports as a SET
   (leaf + chain); the key-bearing leaf wasn't necessarily first.

## ROOT CAUSE
`LoadFleetCertContext` blindly took the first cert from the imported PFX store and
handed it to WinHTTP. On the perso station the key-bearing leaf was not the first cert
returned, so WinHTTP got a cert with no usable private key → `12185` → empty supervisor
key → `6982`. (The old import flag `CRYPT_USER_KEYSET` also fails on locked-down /
service-context stations with no usable user keyset.)

## FIX (in `src/BprCardQi/BprCardQi.cpp`)
- New `TryImportFleet(importFlags, tag, hStoreOut)` that:
  - imports the embedded fleet PFX with the given keyset flag,
  - **enumerates EVERY cert** via `CertEnumCertificatesInStore`,
  - selects the one whose key is actually acquirable
    (`CryptAcquireCertificatePrivateKey`, SILENT + ALLOW_NCRYPT),
  - `CertDuplicateCertificateContext` so it survives enumeration,
  - logs one `[K3] PFXImport(<tag>) cert#N privKey acquirable=… keySpec=… gle=…` per cert.
- `LoadFleetCertContext` tries **CRYPT_MACHINE_KEYSET first** (no user profile needed on
  locked-down stations), then **CRYPT_USER_KEYSET** fallback for interactive sessions.
- CMake: linked **`ncrypt`** (line 240, windows-64 DLL) for `NCryptFreeObject`.

Confirmed working on the perso station: a `cert#N` reports `acquirable=1`, WinHTTP sends,
`HTTP status=200`, supervisor APDU returns `9000`, perso completes.

## Key facts to remember (WinHTTP mTLS from an embedded PFX)
- WinHTTP client-auth re-opens the key from a **named container** → never rely on an
  ephemeral / no-persist key.
- A PFX is a **set** of certs — always pick the cert by **acquirable private key**, not
  by position.
- 12185 = client cert has no usable private key (device-side, request never sent).
  0x8009200B = CRYPT_E_NO_KEY_PROPERTY (that specific cert has no key).
- Perso stations are locked-down/service-context → prefer **MACHINE keyset**.

## Build / state at fix time
- DLL: `build/bnprs-libs/BprCardQi/v2.56.3/windows-64/libBprCardQi.dll`
  sha256 `0538a84fec56970a78325abd0de1f64fba62f66e1e49b8179f69ae66a64e1f45`, size 17,108,017, clean build.
- bpr.cpp **NOT committed** (HEAD `f1cf1e3`). Changed files: `CMakeLists.txt`,
  `cli/BprCardQi/BprCardQi_dll_exports.cpp`, `src/BprCardQi/BprCardQi.cpp`,
  `src/BprScripts/QiScript/{apdu_qi_write_central_perso.cpp, apdu_qi_write_central_preperso.cpp, .h}`.
  (The central-perso/preperso BIXAPP_K3 + IsBixK3 changes are a SEPARATE workstream in
  the same dirty tree.)

## Pending before release (do NOT commit until user says perso fully signed off)
1. Bump 2.56.3 → 2.56.4 (immutable-release rule).
2. Strip temporary debug logging: `[K3]`, `[IP]`, `[IP-D]` (keep maybe one concise
   `[K3] status=` line if useful, but per convention remove the verbose probe logs).
   The `CHALLENGE LENGTH BAD` guard can stay — it's a cheap real safety check.
3. Clean rebuild, then commit + publish on explicit user go-ahead.

Related: grc-kms `[[k3-verifychallenge-health-2026-06-01]]`; cpp-card-qi nucleus
(fleet cert read-only, changes coordinated with na-003/007).
