# Design — BNPRS Global License (BGL) v1

> Author: bnprs-lib-license (na-003/011) · Role: product-architect plan · Date: 2026-06-01
> Status: **draft for approval** · Scope: one licensing scheme for every bpr.cpp library
> across Windows, macOS, iOS, Android, Linux, Raspberry.
> Supersedes the legacy symmetric `BprLicense::patIsValidLicense` scheme (kept as a bridge).

---

## 0. Executive summary

**BGL** is an **offline-verifiable, asymmetrically-signed license token** bound to a
**hardware id (desktop/server/Pi)** or **application id (mobile)**, scoped to a **product**
(from the product-code registry), a **platform set**, **features**, and an **expiry**.
Licenses are **signed by a private key this agent holds** (encrypted at rest on the issuer
host, value never committed) and verified by a **public key compiled into each library** —
so the distributed binary can *verify but never forge*, fixing the core weakness of the
legacy symmetric scheme (where the same key both signs and verifies).

Verification is a tiny, dependency-light **C function (`bgl_verify`)** that links into every
lib and wraps cleanly for Java/.NET/Go via na-003/010. **Verification is fully offline** —
no network at any point: no online activation, no phone-home, no CRL fetch. Revocation, when
needed, is handled offline (short expiry + re-issue, or a signed blocklist bundled with
library/public-key updates).

## 1. Requirements

| # | Requirement |
|---|-------------|
| R1 | One scheme, all libs (product-scoped via the registry's `product_id`) |
| R2 | All platforms: Windows, macOS, iOS, Android, Linux, Raspberry |
| R3 | Bind a license to a **hardware id** OR an **application id**, chosen per license |
| R4 | **Offline-only** verification — never any network call; embedded/air-gapped/POS/kiosk/card hosts must work disconnected |
| R5 | Tamper-evident — expiry/product/features/binding cannot be edited without detection |
| R6 | **No signing secret in the distributed binary** (asymmetric) |
| R7 | Expiry + optional features (tiered licensing) + platform scoping |
| R8 | Renewable; revocation is **offline** (short expiry + re-issue, optional signed bundled blocklist) — no online check |
| R9 | Small, portable verifier (pure C, ~1-file crypto) linkable into every lib |
| R10 | Backward bridge to legacy `patIsValidLicense` during migration |

## 2. Threat model (and how BGL answers it)

| Threat | Mitigation |
|--------|------------|
| Copy a valid license to another machine | License signed over the **hwid hash**; other machine's hwid differs → fails |
| Edit expiry / product / features | Ed25519 **signature over the whole payload** → any edit breaks it |
| Extract a symmetric key from the binary | N/A — only the **public** key is in the binary |
| Forge a license | Requires the **private signing key** (held offline by the issuer) |
| Replay after expiry | `exp` check + **anti-rollback high-water mark** (store last-seen time locally) |
| Clock set backwards | Monotonic high-water mark (last-seen time stored locally) — no online time check |
| VM/image cloning to copy hwid | Multi-component hwid; a perfect clone shares hwid (residual risk — mitigate with a volatile component and/or short expiry) |
| Revocation without network | No online CRL; rely on **short expiry + re-issue**, or a **signed blocklist bundled** with library/public-key updates (documented latency) |

## 3. Token format — `BGL1`

Compact, self-describing, JWT-like but binary payload:

```
BGL1.<base64url(payload)>.<base64url(ed25519_signature)>
```

- `BGL1` = scheme + version prefix (enables clean format evolution).
- `payload` = canonical **CBOR map** (compact, deterministic encoding for signing).
- `signature` = Ed25519 over the exact payload bytes.

### Claims (payload)

| key | type | meaning |
|-----|------|---------|
| `v`   | int | format version (1) |
| `lid` | bytes(16) | license id (UUID) — audit + revocation |
| `pid` | str / [str] | product_id(s) from the registry (e.g. `"03"`, or `["02","03"]` for a bundle) |
| `bind`| str | `"hwid"` \| `"appid"` \| `"none"` |
| `bid` | bytes(32) | SHA-256 of the normalized hwid/appid (privacy-preserving; raw id never stored) |
| `plat`| [str] | allowed platforms: subset of `[win,mac,ios,and,lin,rpi]`, or `["any"]` |
| `feat`| uint | feature bitmask (per-product tiers); `0` = base |
| `iat` | uint | issued-at (unix) |
| `nbf` | uint | not-before (optional) |
| `exp` | uint | expiry (unix); **absent ⇒ perpetual (requires explicit approval)** |
| `kid` | str | signing key id (enables rotation) |
| `iss` | str | issuer id (e.g. `na-003/011`) |

JSON view (debug only; on-the-wire is CBOR):
```json
{ "v":1, "lid":"7f1c…", "pid":"03", "bind":"hwid",
  "bid":"e3b0c4…(sha256)", "plat":["win","lin"], "feat":3,
  "iat":1782950400, "exp":1814486400, "kid":"bgl-2026", "iss":"na-003/011" }
```

## 4. Crypto & key custody

- **Algorithm**: **Ed25519** (fast, deterministic, tiny keys/sigs, trivially portable in C
  via a TweetNaCl-style single file — no OpenSSL dependency in the libs).
- **Hashing**: SHA-256 for hwid/appid binding values.
- **Key custody (self-managed by this agent — no external HSM dependency)**:
  - **Private signing key** → generated and held by this agent on the issuer host;
    **encrypted at rest** (e.g. age/passphrase-wrapped keystore), **never on disk in the
    clear, never in any shipped artifact, never committed**. Referenced in agent files by
    **alias/key-id only** (per the platform key-material rule). Issuance loads it only in
    memory to sign, ideally on a dedicated/offline issuer machine.
  - **Public verification key(s)** → compiled into each library (and/or shipped beside it),
    selected by `kid`. Multiple keys embeddable → **rotation without breaking old tokens**.
  - **Rotation/compromise plan**: on suspected key compromise, mint a new `kid`, ship libs
    with the new public key, re-issue active licenses, and revoke the old `kid`.
  - *(Optional future hardening — a hardware token / offline signer — can be added later
    without changing the token format; explicitly NOT a dependency for v1.)*

## 5. Binding — hardware id vs application id, per platform

`bid = SHA-256( normalize(components) )`. Two or more **stable** components per platform.

| Platform | Default binding | hwid components |
|----------|-----------------|-----------------|
| Windows | hwid | registry `MachineGuid` + SMBIOS UUID / volume serial |
| macOS | hwid | `IOPlatformUUID` (ioreg) + hardware model |
| Linux | hwid | `/etc/machine-id` + DMI `product_uuid` |
| Raspberry | hwid | `/proc/cpuinfo` Serial + `machine-id` |
| **Android** | **appid** | no reliable hwid (privacy) → bind to app: package id + signing-cert hash |
| **iOS** | **appid** | `identifierForVendor` is not stable hwid → bind to bundle id + team id |

> **Architectural call:** mobile (iOS/Android) defaults to **appid** binding because neither
> OS exposes a stable, permitted hardware id. Desktop/server/Pi default to **hwid**. The
> license `bind` field records which was used, so verification knows what to recompute.
> v1 uses **exact hash match**; hardware change ⇒ re-issue. (Future: M-of-N component
> tolerance for disk/NIC swaps.)

**appid** = reverse-DNS bundle/package id (+ optional code-signing identity).
`bid = SHA-256(appid_canonical)`.

## 6. Verification flow (runtime, fully offline)

```
bgl_verify(token, product_id, &result):
  1. split BGL1.<payload>.<sig>; reject bad version/format
  2. select public key by kid
  3. Ed25519 verify(sig, payload)              → fail ⇒ INVALID_SIG
  4. payload.pid contains product_id?          → no  ⇒ WRONG_PRODUCT
  5. current platform ∈ payload.plat (or any)? → no  ⇒ WRONG_PLATFORM
  6. nbf ≤ now ≤ exp (+ anti-rollback check)   → no  ⇒ EXPIRED / NOT_YET / CLOCK
  7. recompute bid for this host/app == payload.bid? → no ⇒ WRONG_BINDING
  8. (optional) lid ∉ bundled signed blocklist → in  ⇒ REVOKED   (offline; no network)
  9. OK ⇒ return {valid, exp, feat}
```

Reason codes (for diagnostics/support): `OK, INVALID_SIG, WRONG_PRODUCT, WRONG_PLATFORM,
EXPIRED, NOT_YET, CLOCK_ROLLBACK, WRONG_BINDING, REVOKED, MALFORMED, UNKNOWN_KID`.

## 7. Lifecycle

```
ISSUE → VERIFY (repeat, fully offline) → RENEW        [revoke = offline re-issue / blocklist]
```

- **Issue**: `bgl-issue` CLI: inputs (product(s), bind type+value, platforms, features,
  expiry) → **sign (Ed25519)** → BGL token. Appends to the **issuance log** (lid, product,
  binding, expiry, requester, kid). Token is delivered to the customer out-of-band.
- **Verify**: **offline**, every run or on an interval — never contacts a server.
- **Renew**: issue a fresh token with a later `exp`, same `lid` lineage; the client swaps the
  file. (Done out-of-band, same as issuance — no online renewal.)
- **Revoke** (offline): there is no online CRL. Options: let the short `exp` lapse and
  decline to re-issue, or publish a **signed blocklist** of `lid`s bundled with the next
  library/public-key update — clients honor it once that update reaches them (documented latency).

## 8. SDK / API surface (BprLicBase v3 — the verifier)

Pure C, depends only on a bundled Ed25519+SHA-256 (no OpenSSL). Wraps via na-003/010.

```c
typedef struct { int valid; int reason; uint64_t exp; uint32_t feat; int bind; } BglResult;

int  bgl_verify(const char* token, const char* product_id, BglResult* out);
int  bgl_hwid(char* out_hex, size_t len);                 // this machine's hwid hash
int  bgl_appid(const char* declared_app, char* out_hex, size_t len);
const char* bgl_reason_str(int reason);
```

- Tooling (issuer side, this agent owns): `bgl-issue` (sign), `bgl-probe` (print hwid/appid
  per platform for enrollment), `bgl-inspect` (decode/validate a token), `bgl-revoke`.
- Lives in `bpr.cpp/src/AprCommon/BprLicense/` alongside the legacy code.

## 9. Migration from legacy (no big-bang)

1. BprLicBase v3 ships **both** `patIsValidLicense` (unchanged) and `bgl_*`.
2. **Dual-accept window**: a lib may accept a legacy qiCode *or* a BGL token.
3. Libs migrate call sites `patIsValidLicense("…","code4")` → `bgl_verify(token, product_id)`
   per the registry's `code4 ↔ product_id` mapping (already defined in `product-codes.yaml`).
4. Once all call sites move, legacy is deprecated (kept for already-issued licenses until exp).

## 10. Cross-agent integration

| Agent | Role in BGL |
|-------|-------------|
| **na-003/009 bnprs-lib-forge** | Publishes **BprLicBase v3** (and the public-key bundle) |
| **na-003/010 bnprs-lib-multisdk** | Wraps `bgl_*` for **Java/.NET/Go** consumers |
| **na-004 / na-005** | Migrate their libs' license call sites to `bgl_verify` |

> Signing-key custody is **self-managed by this agent** (no na-003/007 HSM dependency).

## 11. Phased roadmap

| Phase | Deliverable |
|-------|-------------|
| **0** (done) | This design + product-code registry |
| **1** | Freeze BGL token spec; generate **test** Ed25519 keypair; implement `bgl_verify` + `bgl_hwid` for **desktop (win/mac/linux)** in BprLicBase v3; unit + KAT tests |
| **2** | Mobile **appid** binding (iOS/Android) + Raspberry hwid; `bgl-issue` + `bgl-probe` CLIs; issuance log; **harden signing-key custody** (encrypted keystore on a dedicated issuer host) |
| **3** | **Offline revocation** (signed blocklist bundled with lib/public-key updates); anti-rollback high-water mark; hardware-change tolerance (M-of-N) |
| **4** | Migrate lib call sites (dual-accept) → deprecate legacy |

## 12. Decisions for the product owner (flagged, not blocking)

1. **Offline-only** verification — **confirmed** (no network at any point; revocation via expiry/re-issue or bundled signed blocklist).
2. **Asymmetric Ed25519** with a **self-managed, encrypted-at-rest signing key** (no HSM dependency) — recommended over legacy symmetric.
3. **Mobile = appid, desktop = hwid** default binding — confirm acceptable.
4. **Expiry policy** — subscription (always set `exp`) vs perpetual-with-support-window? Default: always set `exp` (shorter expiry is the main revocation lever in an offline model).
5. **Hardware-change tolerance** — exact hwid match in v1 (re-issue on change), M-of-N later? Confirm.
