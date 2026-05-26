# rnd-superapp — AandhiPe Super-App R&D and Competitive Analysis Agent

## Identity

- **Agent code:** na-100/002
- **Name:** rnd-superapp
- **Role:** R&D and competitive intelligence for BPR2001 AandhiPe super-app
- **Group:** na-100-gne-esrever (reverse engineering / R&D)
- **Status:** active

## What This Agent Manages

R&D work for the BNPRS AandhiPe super-app (BPR2001). The agent covers:
1. Competitive APK analysis of reference super-apps (SuperQi, WeChat, ONDC)
2. Architecture decisions for AandhiPe
3. Mini-program ecosystem, payment architecture, and biometric auth research

## Product: BPR2001 AandhiPe

AandhiPe is the BNPRS consumer super-app — a biometric-authenticated digital payments and services platform targeting the Indian market. Domain: `aandhipe.in`.

**Source repo:** `/Users/bnprs/BPR/GitRepos2/BPR2001_AandhiPe/`

## Competitive / Reference Analysis

Located at: `/Users/bnprs/BPR/GitRepos2/BPR2001_AandhiPe/_bkup/`

---

### SuperQi v1.0.48 — `bpr2001.misc.superqi/`
*Analysis: 2026-03-10 | Package: `iq.qicard.qipay.prod` | 82 MB*

**Most strategically relevant** — SuperQi is the Qi Card (Bank of Baghdad, Iraq) super-app. Qi Card is the same card ecosystem that BNPRS's BRUID/BIX applet targets. SuperQi is built on **Alibaba/Ant Group mPaaS** (white-label Alipay platform), signed by Ant Group.

**Architecture:**
- Platform: Alibaba mPaaS (Mobile Platform as a Service)
- Language: Kotlin 2.1.10 + Java; Gradle 8.7; Min SDK 23; Target SDK 35
- Main class: `com.adw.wallet.application.LauncherApplication`

**Core capabilities:**
- Digital Wallet: QR code payments, NFC card emulation (HCE)
- Card Payments: Full 3DS authentication via Finon SDK + EMVCo 3DS
- KYC / Identity: **NFC passport/ID scanning**, OCR, face liveness — Regula Forensics SDK
- **Mini-Program Ecosystem**: Embedded **Alipay Griver runtime** (dynamically loaded mini-apps)
- Money Transfer: P2P via contact list
- Bill Payments & Marketplace
- Dual GMS/HMS (Google + Huawei) support

**Biometric auth:** `USE_BIOMETRIC` / `USE_FINGERPRINT` — on-device biometric login

**Network endpoints (production):** `banqi.qi.iq` — SSL certificate pinning in place

**Key insight for AandhiPe:** Griver mini-program runtime is the Alipay standard — compare with PhonePe Switch SDK and WeChat AppBrand for AandhiPe mini-app architecture decision.

Source: `bpr2001.misc.superqi/app/` (Gradle project rebuilt from APK); JADX output in `jadx/`

---

### WeChat v8.0.58 — `bpr2001.misc.wechat/`
*Analysis: 2026-03-11 | Package: `com.tencent.mm` | 246 MB*

**Architecture reference** — WeChat is the gold standard for super-app architecture.

**Key architectural patterns:**
- **Plugin architecture:** all features isolated as `com.tencent.mm.plugin.*` plugins; hot-loadable
- **Mini Programs (AppBrand):** `AppBrandProcess0–4` sandboxed processes; V8 JS engine (`libmmv8.so`, `libmmnode.so`); WeChat package manager (`WepkgMainProcess`)
- **Multi-process:** Main + CoreService + AppBrand × 5 + GameWebView + Luggage (webview isolation) + RemoteService
- **Payments (WeChat Pay):** NFC tap-to-pay; QR; HCE; plugin-isolated payment module
- **Storage:** WCDB (encrypted SQLite fork); MMKV (mmap key-value)
- **Networking:** Mars (custom Tencent protocol); OkHttp; Cronet (Chromium)
- **Hot-patch:** Tinker + MMDiff custom patch system — enables feature updates without full APK update
- **Flutter:** Embedded Flutter runtime for some UI surfaces
- 177 native `.so` files; 16 DEX files; ~189,000 Java classes

**Key insight for AandhiPe:** WeChat's plugin + AppBrand multi-process sandboxing is the most robust mini-app architecture. Process isolation prevents mini-app crashes from affecting the host app.

Source: `bpr2001.misc.wechat/_analysis/`

---

### ONDC "Network How to Shop" v2.0.0 — `bpr2001.misc.ondc/`
*Analysis: 2026-05-27 | Package: `org.ondc.shopguide` | 19 MB*

Buyer-side ONDC guide and onboarding app. React Native (Hermes JS engine).

**Core functions:**
- Content-driven onboarding (Strapi CMS backend)
- **QR Code Scanning:** MLKit + ZXing → scans `beckn://` deep-link QR codes
- **App Discovery:** enumerates apps supporting `beckn://` URI scheme; hands off to buyer apps
- **Deep Link Dispatch:** opens Beckn-compatible buyers via `beckn://ret11` (retail), etc.

**Tech stack:** React Native + Hermes; Gradle 8.2.1; Min SDK 23; Play-distributed split APK

**Rebuild artifacts:** decoded (apktool), rebuilt, aligned, signed with debug key (`ondc_debug.keystore`); all steps verified. Output: `ondc_rebuilt_signed.apk`

**Key insight for AandhiPe:** ONDC Beckn protocol integration is a strategic differentiator — AandhiPe should support `beckn://` deep-links for ONDC buyer-app discovery. ONDC's React Native approach is lightweight; contrast with PhonePe's native Switch SDK ecosystem.

Source: `bpr2001.misc.ondc/` — decoded in `ondc_decoded/`, JADX in `ondc_jadx_src/`, JS decompiled in `ondc_js_decompiled.js`

---

### PhonePe v26.02.13.0 — `bpr2001.misc.phonepe/`
*(See also: na-100/001 rnd-mpos for mPOS-specific analysis)*

Super-app perspective:
- **PhonePe Switch**: mini-app ecosystem for hosting 3rd-party merchant apps
- **ONDC vs Switch toggle**: native support for both PhonePe Switch merchants and ONDC network merchants in same app
- Juspay HyperSDK for multi-PSP payment orchestration
- 13 DEX files (144 MB) — large super-app surface area

## Architecture Recommendations (work in progress)

| Decision | Options | Notes |
|----------|---------|-------|
| Mini-app runtime | Alipay Griver vs. WeChat AppBrand vs. custom | SuperQi uses Griver (mPaaS); WeChat AppBrand is more battle-tested |
| Payment orchestration | Direct PSP vs. Juspay HyperSDK | PhonePe uses Juspay for multi-bank routing |
| ONDC integration | Beckn deep-link + native buyer app vs. embedded | ONDC app is thin shell; full integration needs native Beckn client |
| Hot-patch | Tinker vs. Firebase AppDistrib | WeChat Tinker is robust; Firebase simpler for initial release |
| Process isolation | Single-process vs. WeChat multi-process | Adopt for mini-apps once ecosystem grows |

## Inter-Agent Dependencies

- **na-003/005 bnprs-websites** — aandhipe.in domain and web presence
- **na-005/001 cpp-icba-all** — ICBA biometric auth to be integrated in AandhiPe
- **na-005/002 cpp-card-qi** — Qi card digital wallet integration
- **na-100/001 rnd-mpos** — Shared competitive analysis (PhonePe); mPOS + super-app overlap

## Guardrails

- Decompiled APK sources are for internal competitive analysis only — do not redistribute
- Rebuilt/re-signed APKs (debug keystore) must not be published to any app store
- `ondc_debug.keystore` password (`android123`) is for local test only — never use for production
- Production architecture decisions must be reviewed against Play Store / App Store policies before implementation
