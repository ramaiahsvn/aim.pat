# k3-verifychallenge — production health verification (2026-06-01)

> **RESOLVED 2026-06-01.** The empty string was a **device-side** WinHTTP client-cert
> bug, NOT a KMS fault (KMS proven healthy here). Root cause + fix recorded on the
> cpp-card-qi side: na-005/002 `k3-supervisor-key-empty-string-fix-2026-06-01`.
> Summary: WinHTTP got a chain cert without a usable private key (12185 /
> CRYPT_E_NO_KEY_PROPERTY); fixed by enumerating the PFX and picking the cert whose
> key is actually acquirable, importing into MACHINE keyset first. No KMS/cert change
> was needed — fleet cert untouched.


Triggered by na-005/002 cpp-card-qi reporting `QiVerifyChallengeK3Api returned empty string`
during card perso (manifesting as APDU `6982` on the supervisor/EXTERNAL-AUTH step).

## Verdict: KMS service is HEALTHY — empty string is device-side, not server-side.

Verified live from build host (pat-m4p) using the fleet client identity reconstructed
from the embedded PFX (`src/BprCardQi/k3_fleet_cert.h`):

| Check | Result |
|-------|--------|
| Embedded PFX parse (RC2-40-CBC, empty pwd) | OK with `-legacy` (Windows PFXImportCertStore handles natively) |
| PFX private key matches cert | YES |
| Embedded cert == issued `bpr-cardqi-fleet.cert.pem` | YES (sha256 match) |
| Fleet cert validity | to 2036-05-15 |
| Chain to `k3 Device CA` | verify OK |
| API GW mTLS truststore CA == fleet signing CA | YES (sha256 match) |
| API GW route | `POST /verify-challenge` → integration → Lambda (AWS_PROXY) |
| Custom domain mapping | `kms.bnprs.ai` → API `8nlf3cfyd9` stage `prod` |
| Live `curl --cert fleet -k` POST {challenge:16hex} | **HTTP 200**, body `{"response":"<16 hex>"}` |
| Lambda invocations after the test | present (8 events / 30 min) — full path runs end-to-end |

`-k` was required only because *this Mac's* curl CA bundle can't chain the server's
public ACM cert ("unable to get local issuer"); Windows WinHTTP uses the OS store
(trusts Amazon roots) so that is NOT a device issue.

## Key field observation
Before the test, the Lambda log group had **ZERO events in the prior 48h** —
i.e. no real perso device had ever successfully reached the Lambda. mTLS rejections
at the API GW edge return **403 without invoking the Lambda** (no Lambda log).
Combined with the healthy server, this points to the device never completing the
HTTPS call.

## Server contract that silently yields empty (for cpp-card-qi to honor)
- Challenge body must be **exactly 16 hex chars** (8 bytes). Otherwise Lambda → 400
  `{"error":"challenge must be 16 hex chars"}` → no `response` field → client parses empty.
- Endpoint: `POST https://kms.bnprs.ai/verify-challenge`, body `{"challenge":"<16hex>"}`,
  success `{"response":"<16hex>"}`.

## Likely device-side root causes (handed to na-005/002)
1. Perso workstation has no network egress / proxy to kms.bnprs.ai (most likely — explains zero field invocations).
2. Challenge not exactly 16 hex (trailing SW 9000 appended, wrong length).
3. WinHTTP server-cert trust on a locked-down/offline station.

New `[K3]` diagnostic logging was added to `QiVerifyChallengeK3Api` (DLL sha
`e4affd7839d3d335649368a4e83a6adc8db45248d38e51f818a0f7895e5ce06f`) to pinpoint
which step fails: cert-load, each WinHTTP call + GetLastError, HTTP status, body length, parse result.

Related: [[key-registry]] · cpp-card-qi nucleus (na-005/002).
