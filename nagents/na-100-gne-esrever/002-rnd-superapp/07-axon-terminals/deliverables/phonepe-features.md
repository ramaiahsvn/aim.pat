# PhonePe Feature Documentation

---

## 1. Payments

### UPI Payments
- **P2P transfers** — send/receive money via UPI to any VPA (Virtual Payment Address)
- **QR code payments** — scan merchant UPI QR codes using on-device MLKit (TFLite, no network needed)
- **NFC / Tap-to-Pay** — HCE (Host Card Emulation) via `CardsTapPayService` and `CardsTapPayConfirmationActivity`
- **UPI Intent / Collect** — both push and pull payment flows
- **UPI Circle** — delegated payment authority (`UPICircleReceiver`)
- **OTP auto-read** — `SMSBroadcastReceiver` + NPCI regex rules (`npci_otp_rules.json`) silently extract OTPs from bank SMS
- **Multi-bank routing** — Juspay Godel dynamically picks the highest-success-rate bank/PSP; automatic retry on failure

### Card Payments
- **Credit/debit card payments** — full 3DS authentication via Juspay Godel + EC SDK
- **Card tokenisation** — partner: Verestro (`services-phonepe.verestro.com`); certificate pinning enforced
- **RSA 4096-bit card encryption** — `CARD_ENCRYPTION` key v10 in `assets/public_key_params_prod`
- **Tap-to-Pay (NFC cards)** — `Navigator_CardsActivity`, `CardsTapPayConfirmationActivity`

### Bill Payments
- **BBPS** (Bharat Bill Payment System) — deep-link scheme `bbps://`
- **Utility bills, insurance premiums, subscription renewals** — via BBPS network

### International Payments
- **International remittance** — `Navigator_ManageInternationalActivity`
- **Country selection endpoint** — `international-roaming.phonepe.com/country-selection`

### Payment Payload Security
- RSA 4096-bit payload encryption (`PAYLOAD_ENCRYPTION` key v3)
- HMAC-SHA256 payload signing (BouncyCastle)
- Per-transaction nonce via `SecureRandom` (16 bytes → 32-char hex)
- UPI signing cert: IDRBT Sub CA 2022 (`upinpci`, valid to Sep 2025)
- eRupee NPCI cert embedded (expired Oct 2024 — see Security §4)

---

## 2. Authentication & Security

### User Authentication
- **mPIN** — 4-digit PIN, BCrypt cost=12 hashed (never stored plaintext), backed by Room DataStore
- **Biometric login** — `USE_BIOMETRIC` + `USE_FINGERPRINT` permissions; on-device only
- **SMS OTP** — for new device login and UPI onboarding; auto-read via `READ_SMS`
- **UPI onboarding** — `Navigator_UpiOnboardingActivity`

### Device Security
- **Root/tamper detection** — queries 22 known root packages (Magisk, SuperSU, Xposed, LuckyPatcher, etc.) via `<queries>` manifest entries
- **Device binding** — `X-Device-Key` header (SHA-256 hash of ANDROID_ID + model + build fingerprint)
- **Screen lock integration** — `PhonePeLockService`
- **Certificate pinning** — OkHttp pinning active for PhonePe APIs; also for Verestro (Certum CA) and MCP (DigiCert G2 + Entrust G2)

---

## 3. KYC & Identity Verification

- **Aadhaar-based KYC** — `KYC` activity group; `kyc.phonepe.com` endpoint
- **Camera capture** — CameraX-based document/face capture
- **Signature capture** — `SignatureCaptureActivity`
- **Offline KYC** — offline verification flow
- **OCR** — document text extraction (referenced in activity list)
- **Staging KYC** — `kyc-stage-internal.phonepe.com` (internal; present in production build)

---

## 4. Financial Products

### Lending
- **Quick Loans** — instant personal loan application flow
- **LAMF** — Loan Against Mutual Funds
- **Credit score** — powered by Upswing SDK (Experian/CIBIL score, repayment history, EMI eligibility)
- **BNPL / personal loan offers** — pre-qualification based on spend and credit profile

### Insurance
- **Health insurance**
- **Motor insurance**
- **Travel insurance**
- **Life / Term insurance**
- **Sachet insurance** — micro-insurance products

### Investments
- **Mutual funds** — buy/sell/SIP
- **Digital gold** — buy/sell physical gold digitally
- **ELSS** — tax-saving equity linked savings scheme

---

## 5. Mini-App Ecosystem (PhonePe Switch)

- **Proprietary mini-app runtime** — React Native JS bundles loaded by `ReactInstanceManager` (Hermes JS engine)
- **Partner mini-apps** — Swiggy, Ola, Myntra, and others as `.ppsw` signed bundles
- **Switch SDK for merchants** — `@phonepe/switch-sdk` (npm), `phonepe-switch bundle` CLI, signed `.ppsw` bundle format
- **JS-to-native bridge** — `com.phonepe.switch.bridge` exposes Payment API, User Identity API, Analytics API to mini-app JS
- **Runtime CDN** — `com.phonepe.switch.cdn` fetches `.ppsw` bundles at runtime from PhonePe CDN
- **Sandbox isolation** — mini-app JS restricted to Switch SDK bridge APIs only; cannot access host app memory
- **Deep-link launch** — `phonepe://switch/<appId>` opens specific mini-apps from external apps or banners

---

## 6. ONDC Integration (Open Network for Digital Commerce)

- **ONDC buyer-side node** — "Store" and "Food" sections surface ONDC-registered sellers
- **Beckn protocol** — interoperates with any ONDC-compliant seller app
- **Dual model** — Switch (curated, premium partners) + ONDC (open, long-tail sellers) coexist in the same app
- **Deep-link scheme** — `bharatconnect://` for BharatConnect; standard `upi://` for ONDC payment handoff

---

## 7. Maps & Location

- **Mappls (MapMyIndia) SDK v9** — India-first maps; nearby ATMs, merchants, banks; Survey of India data
- **Mapbox SDK v10** — global maps; custom tiles; route/delivery tracking
- **Permissions** — `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`
- **Use cases** — merchant discovery, UPI QR location tagging, delivery tracking

---

## 8. Chat & Social

- **P2P Chat** — `Navigator_ChatActivity`
- **Group Chat** — `Navigator_GroupActivity`
- **Chat push notifications** — `P2PChatBroadcastReceiver`

---

## 9. Ads & Rewards

- **Rewarded ads** (AdMob) — user-initiated "Watch & Earn" format; AdMob App ID `ca-app-pub-7497871399275516~6791896171`
- **Ad serving** — `ads.phonepe.com/apis/adserve/`; Google DoubleClick; Google Ad Serving
- **Google Privacy Sandbox** — `ACCESS_ADSERVICES_*` (3 permissions) for on-device ad targeting

---

## 10. Analytics & Attribution

| SDK | Purpose |
|-----|---------|
| Firebase Analytics | User event tracking |
| Firebase Crashlytics | Crash reporting |
| Firebase Messaging | Push notifications |
| Sentry | Error tracking and performance monitoring |
| AppsFlyer | Install attribution (Privacy Sandbox) |
| Facebook SDK | Install attribution + payment event reporting to Meta |
| Upswing | Credit analytics and spend categorisation |

**Custom analytics events tracked:** `CompletedRegistration`, `Purchase`, `InitiatedCheckout`, `QrScan_Opened`, `MiniApp_Launched`

---

## 11. Background & System Services

| Service / Receiver | Purpose |
|--------------------|---------|
| `MobileVerificationService` | SMS OTP verification (UPI device binding) |
| `CardsTapPayService` | NFC HCE tap-to-pay background service |
| `BLEAdvertiseService` | Bluetooth LE for nearby/proximity payments |
| `TransactionNotificationService` | Payment push notifications |
| `MicroAppService` | React Native micro-app runtime host |
| `PlayModuleDownloadService` | Dynamic feature module delivery (Play) |
| `SyncAlarmReceiver` | Periodic background data sync |
| `RECEIVE_BOOT_COMPLETED` | Auto-start on device boot |
| WorkManager (6h periodic) | Transaction history sync via `TransactionSyncWorker` |

---

## 12. Deep Links & URI Schemes

| Scheme | Purpose |
|--------|---------|
| `phonepe://` | Native PhonePe deep links |
| `upi://` | Standard UPI deep links (QR payments) |
| `ppE://` | PhonePe encoded short links |
| `credpay://` | CRED Pay integration |
| `mandate://` | UPI mandate / recurring payment flows |
| `checkout://` | Checkout flows |
| `bbps://` | BBPS bill payments |
| `bharatconnect://` | BharatConnect / ONDC |

**Universal link domains:** `www.phonepe.com/applink`, `phon.pe/app`, `ppe.onelink.me`

---

## 13. Developer / Debug Tooling (in production build)

> Note: these are present in the production APK — relevant for AandhiPe architecture decisions (do not ship in production).

| Tool | Type | Risk |
|------|------|------|
| `DevelopmentToolsActivity` | Activity | Medium |
| `FeatureFlagActivity` | Activity | Medium |
| `LiquidUIDevModeActivity` | Activity | Medium |
| `EventBrowserActivity` | Activity | Medium |
| `TestForegroundService` | Service | Low |
| Chucker HTTP Inspector | HTTP interceptor (all traffic) | Medium |
| Sherlock remote command framework | Remote debug/diag plane | Medium-High |

---

## Feature Summary for AandhiPe Planning

| PhonePe Feature | AandhiPe Relevance | Priority |
|----------------|--------------------|----------|
| UPI P2P + QR payments | Core — mandatory | P0 |
| Biometric auth (on-device) | Core — ICBA integration (na-005/001) | P0 |
| mPIN + BCrypt | Core — replicate pattern | P0 |
| NFC tap-to-pay (HCE) | Core — Qi card + BIX applet (na-005/002) | P0 |
| BBPS bill payments | High value for Indian market | P1 |
| Mini-app runtime (Switch) | AandhiPe ONDC/mini-app architecture decision | P1 |
| ONDC buyer node | Strategic differentiator | P1 |
| Juspay HyperSDK (Godel/EC) | Multi-bank routing — evaluate for AandhiPe | P1 |
| KYC (Aadhaar, camera, OCR) | Compliance — required for wallet/lending | P1 |
| Mutual funds / digital gold | Phase 2 financial products | P2 |
| Insurance products | Phase 2 | P2 |
| Rewarded ads (AdMob) | Revenue model option | P2 |
| Chat (P2P, group) | Phase 2 social layer | P2 |
| International remittance | Phase 3 | P3 |
| Credit score (Upswing) | Phase 3 — lending vertical | P3 |
