---
name: project-na100-agents
description: "na-100-gne-esrever: reverse-engineering R&D group; 3 active agents (001–003) covering mPOS, AandhiPe super-app, and card personalization (Perso)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cd3a02c-667d-4ad2-a5bb-49b30d3c7376
---

na-100-gne-esrever is the reverse-engineering R&D group ("gne-esrever" = "reverse.eng" backwards). Created 2026-05-27.

- 001 rnd-mpos — BPR1003 PatPOS mPOS R&D; multi-vendor Android POS (Sunmi/Futronic/HYF/Q2/PAX); biometric (finger/iris/face) + Qi card reads; competitive reference: PhonePe APK analysis (Juspay HyperSDK, Switch SDK mini-apps, ONDC integration); source: `BPR1003_mPOS/`
- 002 rnd-superapp — BPR2001 AandhiPe super-app R&D; competitive references: SuperQi (Alibaba mPaaS/Griver, Qi Card Iraq, 3DS, Regula KYC), WeChat (plugin arch, AppBrand mini-programs, Tinker hot-patch, Mars protocol), ONDC "How to Shop" (React Native, Beckn deep-links); source: `BPR2001_AandhiPe/`; competitive analysis: `BPR2001_AandhiPe/_bkup/`
- 003 rnd-cperso — Card Personalization (Perso) R&D; created 2026-05-30; data prep, key management (HSM, UDK derivation — IDs/labels only, no key values), EMV CPS, GlobalPlatform SCP02/SCP03 perso, APDU perso scripts; standards: EMVCo CPS, GP Card Spec, ISO 7816, PCI Card Production; consumed by na-005-bnprs-fintech (Qi/EMV smart card, BIX/BRUID applets). **Source repo:** `GitRepos2/TRP1002_cPerso` (cPerso, MCES2 Qi/EMV perso system). **Allowed working paths (strict allowlist, user grants more on request):** `TRP1002_cPerso/trp1002.cperso.mces2/BprDataPrep` (data prep / embossing / PersoScripts) and `TRP1002_cPerso/trp1002.cperso.thales` (Thales/Gemalto perso, ISPI4MLB2, EMV perso engine). Related but NOT in scope until granted: `TRP1003_pHsm` (Thales KMS).

**Backup path:** `/Users/bnprs/BPR/GitRepos2/BPR2001_AandhiPe/_bkup/` — contains rebuilt/decompiled APKs (bpr2001.misc.ondc, bpr2001.misc.phonepe, bpr2001.misc.superqi, bpr2001.misc.wechat). For internal R&D only — do not redistribute.

**Why:** Competitive intelligence and reverse-engineering R&D to inform BNPRS product architecture decisions (mini-app ecosystems, payment orchestration, ONDC Beckn integration).

**How to apply:** When user references mPOS hardware integration, AandhiPe features, super-app architecture, PhonePe/WeChat/SuperQi/ONDC competitive analysis — point to na-100 agents. Source repos: `/Users/bnprs/BPR/GitRepos2/BPR1003_mPOS/` and `/Users/bnprs/BPR/GitRepos2/BPR2001_AandhiPe/`.
