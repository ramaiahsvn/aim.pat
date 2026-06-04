# BGL Fleet Enrollment + Issuance API — spec v1 (draft 2026-06-04)

Owner: **na-003/011 bnprs-lib-license**.  Issuance backend: **na-003/007 bnprs-grc-kms**.
Build of DLL + enrollment exe: **na-005/002 cpp-card-qi**.

Goal: auto-license **existing BprCardQi Windows workstations**. A small exe run on each station
collects the machine's hwid, asks the grc-kms signing API for a signed BGL token, and drops it at
`C:\ProgramData\BprCardQi\<hwid>.lic`. BprCardQi then loads that file and unlocks (the BGL global
gate at `BprPcSc_Context_Init`).

This complements the FROZEN wire spec (`bpr.cpp/src/AprCommon/BprLicense/bgl/BGL-TOKEN-SPEC.md`) —
it does **not** change the token format or the verifier. Only the *issuance path* is new.

---

## 1. Trust model (what changed, what didn't)

| Property | Decision |
|---|---|
| **Signing key custody** | Moves into **grc-kms** (KMS/HSM), exposed via a signing API. Reverses the earlier "self-managed bgl.key on pat-m4p, no grc-kms/HSM dependency" pillar. |
| **Issuance** | **Online** — workstation → grc-kms API → signed `.lic`. |
| **Verification (runtime)** | **Unchanged, fully offline.** The lib verifies the token against the Ed25519 public key compiled into it (`bgl_pubkeys.h`). No network at verify time. |
| **Forge surface** | The signing API is now the single forge point — it MUST be authenticated/authorized (see §7). The private key never leaves grc-kms; it is never in the exe or the lib. |

> The offline-only guarantee was always about the **verifier**, not issuance. An online issuance API
> is therefore compatible: a token, once minted, still verifies with no network.

## 2. Fleet token claims profile

Every fleet license for these workstations carries:

| Claim | Value | Why |
|---|---|---|
| `products` | `[3]` (BprCardQi) | per `product-codes.yaml` (product_id 3). May add more ids if a station is multi-lib. |
| `bind` | `hwid` (1) | desktop binding; `bid` = `SHA-512(MachineGuid "\n" volserial)[:32]`. |
| `bid` | the station's 64-hex hwid | supplied by the exe (`bpr_cardqi_hwid`). |
| `plat_mask` | `0x01` (bit0 = Windows) | locks the token to Windows. |
| `exp` | `0` = **perpetual** | **owner-approved 2026-06-04.** Verifier skips expiry when exp==0. |
| `nbf` | `0` | valid immediately. |
| `lid` | fresh UUID (16B), **logged by grc-kms** | the only revocation handle for perpetual tokens (offline blocklist). |
| `kid` | grc-kms active key id | selects the embedded public key at verify. |
| `feat` | `0` (base) unless specified | feature bitmask. |

## 3. `.req` — enrollment request (workstation → API)

JSON, UTF-8. Written/sent by the exe. Contains **no secret**.

```json
{
  "bgl_req": 1,
  "product_ids": [3],
  "bind": "hwid",
  "bid": "<64-hex hwid from bpr_cardqi_hwid()>",
  "plat_mask": 1,
  "exp_days": 0,
  "feat": 0,
  "station": { "hostname": "POS-0142", "note": "optional, audit only" }
}
```

- `bid` is the already-hashed 64-hex hwid (matches what the lib recomputes locally). The raw
  machine identifiers are **never** sent — only their hash.
- `exp_days: 0` requests a perpetual token. The API enforces policy (see §7) before honoring it.
- Optional `.req` file on disk: `C:\ProgramData\BprCardQi\<hwid>.req` (for offline collection /
  audit; the exe can also POST the same JSON directly).

## 4. `.lic` — issued license file (API → workstation)

- **Content:** exactly the BGL token string `BGL1.<b64url block>.<b64url sig>`, optionally a single
  trailing newline. Nothing else. (The lib trims whitespace.)
- **Path:** `C:\ProgramData\BprCardQi\<hwid>.lic` — `<hwid>` is the same 64-hex string.
  Non-Windows default store: `/var/lib/BprCardQi/<hwid>.lic`.
- **Perms (recommended):** readable by the service account that runs BprCardQi; not world-writable.
  The file is **not secret** (it only works on its bound machine) but should not be tamperable by
  unprivileged users.

## 5. Signing API contract (grc-kms — to be built by na-003/007)

**Endpoint (confirmed 2026-06-04):** `https://kms.bnprs.ai/bgl/v1/issue`

```
POST https://kms.bnprs.ai/bgl/v1/issue
Authorization: <enrollment credential — see §7>
Content-Type: application/json

  <body = the .req JSON from §3>

200 OK
Content-Type: application/json
  { "bgl_lic": 1, "token": "BGL1.<...>.<...>", "kid": <n>, "lid": "<uuid>" }

4xx { "error": "code", "message": "..." }   e.g. unauthorized, policy_denied, bad_request
```

- grc-kms validates the request against policy (allowed product_ids, allowed plat_mask,
  perpetual-allowed?), signs the claim block with the active private key (`bgl_sign`), logs
  `{lid, bid, products, plat, kid, requester, time}` to the **issuance log**, and returns the token.
- The claim-encoding + signing logic is BGL's (`bgl_claims_encode` + `bgl_sign` from
  `bpr.cpp/.../bgl/`); grc-kms wraps it around its key store. This agent provides that code/contract;
  grc-kms owns the key and the endpoint.
- Offline fallback (no API reachable at enroll time): the exe writes `<hwid>.req`; an operator
  batch-submits collected `.req`s to the API later and redistributes the `.lic`s.

## 6. Enrollment exe behavior (`bgl-enroll.exe`)

Runs on the workstation, background-safe, **idempotent**, holds **no key**:

1. `bpr_cardqi_hwid(buf, 65)` → 64-hex `hwid`.
2. If `C:\ProgramData\BprCardQi\<hwid>.lic` exists AND `bpr_cardqi_activate_from_store(NULL)`
   returns 0 → already licensed → exit 0.
3. Else build the `.req` (§3) and `POST /bgl/v1/issue`.
4. On 200 → write the returned `token` to `C:\ProgramData\BprCardQi\<hwid>.lic` (create dir if
   needed), then call `bpr_cardqi_activate_from_store(NULL)` to confirm it activates → exit 0.
5. On failure → write `<hwid>.req` for later batch issuance, log, exit non-zero.

Exit codes: `0` licensed, `2` request failed (req saved), `3` hwid unavailable, `4` activation of a
returned token failed (token rejected — likely wrong bind/product/kid → flag to issuer).

## 7. Security requirements (hard)

1. **API authN/authZ (grc-kms):** only authorized enrollment may obtain a signature — e.g. mTLS
   client cert per fleet, or a short-lived enrollment secret + IP/asset allowlist + rate limiting.
   Without this, anyone reaching the endpoint can mint a perpetual license.
2. **Perpetual ⇒ blocklist is the revocation path.** grc-kms MUST log every `lid` issued so a signed
   offline **blocklist** can later be bundled with lib/public-key updates to kill a leaked or
   decommissioned license. (hwid-binding already limits a leaked token to one physical machine.)
3. **Private key:** never in the exe, never in the lib, never logged. Lives only in grc-kms.
4. **No always-true path:** the lib gate still requires a real, signature-valid, hwid+product-bound
   token. File-load only changes *where the token comes from*, not whether it's verified.

## 8. Library integration (this agent — DONE in source, build via cpp-card-qi)

Added to BprLicBase facade `bpr_bgl.{h,cpp}`:
- `BprBgl::activateFromFile(path, productId, appid="")`
- `BprBgl::activateFromStore(storeDir, productId, appid="")` → reads `<storeDir>/<hwid>.lic`.
- Negative codes: `kFileNotFound (-101)`, `kFileEmpty (-102)`, `kHwidUnavailable (-103)`.

Added C ABI exports in `cli/BprCardQi/BprCardQi_dll_exports.cpp`:
- `int bpr_cardqi_activate_from_store(const char* storeDir)` — NULL/"" → default store
  `C:\ProgramData\BprCardQi`; activates `<hwid>.lic`; returns bgl_reason (0==OK) or negative.
- `int bpr_cardqi_license_path(char* outPath, int outCap)` — writes the default `<store>\<hwid>.lic`.

**Lazy auto-load at the chokepoint — APPLIED 2026-06-04 (owner-approved).** So *existing* host apps
pick up a dropped `.lic` with zero app changes, `BprPcSc_Context_Init` now does a one-time lazy load
before failing:

```cpp
int* BprPcSc_Context_Init(int* errorCode) {
    if (!BprBgl::isLicensed()) {
        BprBgl::activateFromStore(cardqi_store_dir(), "3");   // applied: lazy auto-load
        if (!BprBgl::isLicensed()) { if (errorCode) *errorCode = -900; return nullptr; }
    }
    ...
}
```

This preserves verification (the loaded token must still be signature-valid + hwid/product-bound);
it only removes the need for the host app to call `activate` explicitly. `cardqi_store_dir()` =
`C:\ProgramData\BprCardQi` on Windows, `/var/lib/BprCardQi` elsewhere.
**Android JNI `contextInit` is deliberately left unchanged** — mobile uses appid binding and has no
`C:\ProgramData`-style store; mirror the one-liner there only if mobile fleet auto-licensing is ever
scoped.

### Enrollment exe — DRAFTED 2026-06-04
`bpr.cpp/cli/BprCardQi/enroll/bgl_enroll.c` — Windows console app, compile-verified (PE32+,
mingw-w64, `-lwinhttp`). Runtime-loads the deployed `BprCardQi.dll` (identical hwid derivation),
idempotent, holds no key. Online mode POSTs the `.req` to the issuance endpoint — **default
`https://kms.bnprs.ai/bgl/v1/issue`**, overridable via `--api` / `BGL_ISSUE_URL` — with an optional
`Authorization` header (`BGL_ENROLL_AUTH` / `--auth`); `--offline` forces request-only (drops
`<hwid>.req`). Writes `<hwid>.lic` and confirms activation. cpp-card-qi owns the canonical CMake target.

## 9. Ownership / next steps

- [ ] **grc-kms (na-003/007):** stand up `POST /bgl/v1/issue` over its key store; auth; issuance log
      with `lid`. Uses BGL `bgl_claims_encode` + `bgl_sign`.
- [ ] **this agent (na-003/011):** finalize this contract; provide the claim-encode/sign snippet to
      grc-kms; (pending approval) wire the lazy auto-load at the chokepoint.
- [ ] **cpp-card-qi (na-005/002):** build `libBprCardQi.dll` with the new exports; build
      `bgl-enroll.exe` (links BprCardQi for `bpr_cardqi_hwid` + `bpr_cardqi_activate_from_store`).
