# INPUT → na-005/010 bruid-iperso

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-13 · **Priority:** HIGH · **Status:** OPEN
**Source doc (canonical, git-ignored — Confidential/Pointman, do NOT commit the PDF):**
`/Users/bnprs/BPR/GitRepos2/TRP1002_cPerso/trp1002.cperso.thales/Resources/Vendor_Integration_Pointman_v1.3.pdf`
Prepared by MENTA FZ LLC · "Kiosk Instant Card Issuance — Pointman Integration Guide v1.3".

## Why this is yours
This is the **contract for kiosk INSTANT issuance** — exactly the iperso path (`service-type="INSTANT"`,
`destination="KIOSK-001"`). It defines the wire protocol our instant-issuance orchestration + machine
integration must speak. The standalone DPI XML the user shared earlier is literally §7.3 of this doc.

## Role mapping — RESOLVED (user, 2026-07-13)
- **MENTA** = the **perso bureau** (upstream issuer orchestrator, `MentaKioskService`). NOT us — it is the
  customer/source: it sends us the orchestration calls + the DPI perso data, and receives our DUI status.
- **Pointman** = the **kiosk hardware vendor** (the physical kiosk shell).
- **We (BRUID)** = the **perso backend** behind the kiosk. We own **dprep** + **perso-script prep/execution**
  for both **central (bruid-cperso)** and **instant (bruid-iperso)**. The doc's "Pointman machine backend"
  **IS our backend, managed by us.** The `BprCardEmv` engine is ours and does the chip perso.

> **iperso scope — CORRECTED (user, 2026-07-13):** Part A (kiosk frontend) and Part B (MENTA⇄machine SOAP:
> QR Scan Notify, QR Confirmation, DPI receive, DUI send, WS-Security) are being built by **another team
> member on our side — NOT this agent.** **bruid-iperso owns the INSTANT PERSONALIZATION SCRIPT** — the chip
> perso engine in `bpr.cpp/src/BprCardEmv/persoengine`: consume dprep's parsed perso record + keys → emit and
> execute the single-use, card-bound **SCP02 APDU perso script**. The Pointman doc is CONTEXT (defines where
> the data arrives and where the result is reported), not iperso's build surface.

## Two integration surfaces — CONTEXT ONLY (built by the Part A/B team member, not iperso)
- **Part A — Kiosk Frontend → MentaKioskService** (REST/JSON, §6): `GenerateQR`, `ValidateOTP`, `ConfirmArtwork`.
  Kiosk touchscreen UI as REST client of MENTA. Auth: OAuth2 JWT (Keycloak `client_credentials`, **VENDOR**
  role, realm `kiosk-backend`), UAT base `https://<menta-kiosk-uat>/kiosk-card-print`. *(Other team member.)*
- **Part B — MENTA ⇄ machine backend** (SOAP 1.1/HTTPS, §7) — **four operations**, `version="2.0.0"`.
  *Built by the Part A/B team member.* iperso's engine sits **behind** op 3 (consume DPI → build script) and
  **feeds** op 4 (report perso result):

  | # | Operation | Root element | Direction | iperso touchpoint |
  |---|-----------|--------------|-----------|-------------------|
  | 1 | QR Scan Notify | `QRScanNotificationRequest` | MENTA → backend | — |
  | 2 | QR Confirmation | `QRConfirmationRequest` | MENTA → backend | — |
  | 3 | DPI — Card Personalisation | `RequestPersoRequest` | MENTA → backend | **input** (via dprep parse) |
  | 4 | DUI — Print Status | `StatusUpdate` | backend → MENTA | **output** (our perso result) |

  Signing (calls 1–3): WS-Security RSA-SHA1 over the Body (X509IssuerSerial, no timestamp) — handled by the
  transport/Part B layer, not the perso script.

## End-to-end flow (§4)
GenerateQR → customer scans+auths in Super Qi → **QR Scan Notify** (intermediary screen, no OTP, no production)
→ customer selects card → **QR Confirmation** (production mode + OTP sent by SMS) → **ValidateOTP** (returns
`cardProgramId[]`) → **ConfirmArtwork** → **DPI RequestPerso** (encrypted embossing) → machine personalises+prints
→ **DUI StatusUpdate** (`status-code 0 = SUCCESS`).
> Design note: QR Scan Notify and QR Confirmation are deliberately **two calls** (race avoidance — OTP must
> not be enterable before a card is selected). Preserve that split.

## Status + error codes
- **PTM_CP_00XX** (§9.1) — MENTA-**proposed, pending Pointman confirmation**. Key: `0008` valid txn+OTP details
  fetched, `0006` invalid OTP, `0005` OTP expired, `0007` max retry, `0014` Card Creation **Success**, `0013` failed.
  **ACTION:** confirm/adjust these with Pointman.
- **Part A HTTP errors** (§9.2): `VAL-400`, `QR-404`, `QR-001` (410 QR window elapsed), `STOCK-001` (409 out of stock), `SYS-001`.

## Cross-refs
- DPI payload detail is dprep's — see its input `2026-07-13-pointman-dpi-dataprep-v1.3.md`.
- Connects to iperso `task-001.1` (central script-gen) / `task-001.2` (kiosk executor). The Part B SOAP
  contract is the concrete external shape those subtasks were abstractly targeting.

## Action items for bruid-iperso — the INSTANT PERSONALIZATION SCRIPT (bpr.cpp/src/BprCardEmv)
1. Build the instant perso-**script generator** (P5 Sequencer/emitter): consume dprep's parsed perso record +
   `IHsmClient` keys → emit a **single-use, card-bound SCP02 APDU perso script** (STORE DATA + wrapping).
2. Kiosk **executor**: replay the script onto the card over PC/SC, read-back verify, produce the perso outcome.
3. **Coordinate the boundary** with the Part A/B team member: receive the parsed data (after dprep decrypts the
   DPI) at op 3; return the perso result that populates their **DUI** (`PTM_CP_0014` success / `0013` fail).
4. Depends on: **dprep task-001.6** (DPI parse) · **bureau SCP02 ISD keys** (rnd-cperso task-003) · **DGI fix**
   (dprep task-001.4). Can build + dry-run against KATs now, before keys land.

> NOT iperso's scope: Part A frontend, Part B SOAP transport, WS-Security, DUI wire-send — the other team member.
