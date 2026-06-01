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
Licenses are **signed by a private key the issuer holds (ideally in the HSM at
kms.bnprs.ai)** and verified by a **public key compiled into each library** — so the
distributed binary can *verify but never forge*, fixing the core weakness of the legacy
symmetric scheme (where the same key both signs and verifies).

Verification is a tiny, dependency-light **C function (`bgl_verify`)** that links into every
lib and wraps cleanly for Java/.NET/Go via na-003/010. No network is required at runtime;
online is optional, only for activation and revocation.

## 1. Requirements

| # | Requirement |
|---|-------------|
| R1 | One scheme, all libs (product-scoped via the registry's `product_id`) |
| R2 | All platforms: Windows, macOS, iOS, Android, Linux, Raspberry |
| R3 | Bind a license to a **hardware id** OR an **application id**, chosen per license |
| R4 | **Offline** verification — embedded/air-gapped/POS/kiosk/card hosts have no guaranteed network |
| R5 | Tamper-evident — expiry/product/features/binding cannot be edited without detection |
| R6 | **No signing secret in the distributed binary** (asymmetric) |
| R7 | Expiry + optional features (tiered licensing) + platform scoping |
| R8 | Revocable (CRL / optional online check) and renewable |
| R9 | Small, portable verifier (pure C, ~1-file crypto) linkable into every lib |
| R10 | Backward bridge to legacy `patIsValidLicense` during migration |

## 2. Threat model (and how BGL answers it)

| Threat | Mitigation |
|--------|------------|
| Copy a valid license to another machine | License signed over the **hwid hash**; other machine's hwid differs → fails |
| Edit expiry / product / features | Ed25519 **signature over the whole payload** → any edit breaks it |
| Extract a symmetric key from the binary | N/A — only the **public** key is in the binary |
| Forge a license | Requires the **private signing key** (held offline / in HSM) |
| Replay after expiry | `exp` check + optional **anti-rollback high-water mark** (store last-seen time locally) |
| Clock set backwards | Optional monotonic high-water mark; optional online time check when available |
| VM/image cloning to copy hwid | Multi-component hwid + optional **online activation seat count** |
| Use a revoked license offline | Honored until CRL reaches the client or the license expires (documented limitation) |

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
| `seat`| uint | optional activation seat count (online policy) |

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
- **Key custody**:
  - **Private signing key** → held by the issuer; production key **in the HSM at
    kms.bnprs.ai** (coordinate with **na-003/007 bnprs-grc-kms**). Issuance calls the HSM to
    sign. Never on disk in the clear; never in any shipped artifact.
  - **Public verification key(s)** → compiled into each library (and/or shipped beside it),
    selected by `kid`. Multiple keys embeddable → **rotation without breaking old tokens**.
- Per the platform key-material rule: store only **key IDs / aliases**, never key values.

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
  8. (optional) lid ∉ local CRL cache          → in  ⇒ REVOKED
  9. OK ⇒ return {valid, exp, feat}
```

Reason codes (for diagnostics/support): `OK, INVALID_SIG, WRONG_PRODUCT, WRONG_PLATFORM,
EXPIRED, NOT_YET, CLOCK_ROLLBACK, WRONG_BINDING, REVOKED, MALFORMED, UNKNOWN_KID`.

## 7. Lifecycle

```
ISSUE → (ACTIVATE) → VERIFY (repeat, offline) → RENEW → REVOKE
```

- **Issue**: `bgl-issue` CLI/service: inputs (product(s), bind type+value, platforms,
  features, expiry) → HSM signs → BGL token. Appends to the **issuance log** (lid, product,
  binding, expiry, requester, kid).
- **Activate** (optional, online): first run posts `lid + bid` to a license server →
  records activation, enforces `seat` count, returns ack. Offline installs skip this.
- **Verify**: offline, every run or on an interval.
- **Renew**: issue a fresh token with a later `exp`, same `lid` lineage; client swaps it.
- **Revoke**: add `lid` to the CRL; online clients refresh the CRL; offline clients honor
  until CRL arrives or `exp` (documented).

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
| **na-003/007 bnprs-grc-kms** | Holds the Ed25519 **signing key in the HSM** (kms.bnprs.ai); signs at issuance |
| **na-003/009 bnprs-lib-forge** | Publishes **BprLicBase v3** (and the public-key bundle) |
| **na-003/010 bnprs-lib-multisdk** | Wraps `bgl_*` for **Java/.NET/Go** consumers |
| **na-004 / na-005** | Migrate their libs' license call sites to `bgl_verify` |

## 11. Phased roadmap

| Phase | Deliverable |
|-------|-------------|
| **0** (done) | This design + product-code registry |
| **1** | Freeze BGL token spec; generate **test** Ed25519 keypair; implement `bgl_verify` + `bgl_hwid` for **desktop (win/mac/linux)** in BprLicBase v3; unit + KAT tests |
| **2** | Mobile **appid** binding (iOS/Android) + Raspberry hwid; `bgl-issue` + `bgl-probe` CLIs; issuance log; **move signing key to HSM** (na-003/007) |
| **3** | Online **activation** + **CRL/revocation** service; seat counting |
| **4** | Migrate lib call sites (dual-accept) → deprecate legacy |

## 12. Decisions for the product owner (flagged, not blocking)

1. **Offline-first** verification — assumed (embedded/air-gapped reality). Confirm.
2. **Asymmetric Ed25519** with HSM-held signing key — recommended over legacy symmetric.
3. **Mobile = appid, desktop = hwid** default binding — confirm acceptable.
4. **Expiry policy** — subscription (always set `exp`) vs perpetual-with-support-window? Default: always set `exp`.
5. **Revocation** — ship the CRL/online service in Phase 3, or defer (expiry-only) for v1?
6. **Hardware-change tolerance** — exact hwid match in v1 (re-issue on change), M-of-N later? Confirm.
