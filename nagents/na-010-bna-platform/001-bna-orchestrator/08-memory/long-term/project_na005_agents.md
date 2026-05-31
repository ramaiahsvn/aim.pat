---
name: project-na005-agents
description: "na-005-bnprs-fintech: 12 active agents (001–012) covering ICBA, Qi/EMV smart card, APDU scripting, cross-platform PC/SC, JavaCard applets, BRUID issuance, fintech R&D, and mPOS libraries"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cd3a02c-667d-4ad2-a5bb-49b30d3c7376
---

na-005-bnprs-fintech has 12 active agents (codes 001–012):

- 001 cpp-icba-all — ICBA orchestrator (Issuer Controlled Biometric Auth); Windows COM stub, full impl pending
- 002 cpp-card-qi — BprCardQi: Qi smart card I/O, biometric data read (tags 0x4B/4C/4D), embedded mTLS fleet cert (k3_fleet_pfx[], CN=bpr-cardqi-fleet valid to 2036-05-15) → kms.bnprs.ai
- 003 cpp-card-emv — BprCardEmv: EMV smart card, AID-based selection, inherits BprCardQi infrastructure
- 004 cpp-card-pure — BprScripts: QiScript (74-field central perso, 52-field instant perso, reset, admin key inject, ECEBS applet load, GND variant) + PureScript (EMV blob R/W, fingerprint TLV tag 0x4B)
- 005 cpp-pcsc-all — BprPcSc: cross-platform PC/SC (Windows/WinSCard, Linux/PCSCLite, Android 8 vendors: Sunmi/PAX/Feitian/Nexgo/Ciontek/Wizar/Futronic + stubs; TP9000 DLL reader, TTC serial reader)
- 006 k3-bix-applet — BIX JavaCard applet v2.55.2 (biometric storage on chip, 3DES auth, PRE_PERSO/ISSUED lifecycle, AID: A0000003764249584150505F4B33); **IP transferred to Menta**
- 007 bruid-applet — BRUID JavaCard applet; **Patent-3 India, BNPRS-owned**; successor to BIX; no local source repo
- 008 bruid-dprep — BRUID Data Preparation: 74-field central blob + 52-field instant hex assembly; CVV/PVV/ICVV/Track/Pinblock computation; PCI-DSS SAD handling
- 009 bruid-cperso — BRUID Central Personalization: bureau batch issuance; HSM (FM/HOST/HostJNI); BprQiEmv DLL (v2.50.x); Gemalto/Kona/GND variants
- 010 bruid-iperso — BRUID Instant Issuance: branch counter; 52-field hex; remote SupervisorAuthentication via kms.bnprs.ai; 8 Android vendors; re-perso support
- 011 rnd-fintech — Fintech R&D (bpr.rnd): EMV PIN block (ISO 9564-1 F0), DUKPT key management, GlobalPlatform CPS demonstrator, Menta PURE docs, chip perso scripts (Gemalto/eDinar), supervisor key traces, ISO 19794-2 biometric templates; contains UAT/test keys — treat as sensitive
- 012 bpr1003-mpos-libs-usage — BPR1003 mPOS C++ Libraries: PatPOS client-side libraries for mobile point-of-sale (Android + Linux). Active work: mPos.Lib migration replacing old `mPosXxxController → ContactCardImpl → qiemv/qiScript.so` path with new `PcscCardReader → BprPcSc.so` path (matches sunmi.11.2 structure). 6 device library modules migrated (pax, feitian, wizar, nexGo, ciontek, futronic); test app changes complete for pax/MainActivity.java, pending for feitian/wizar/nexGo/ciontek/futronic. hyf and idemia not yet in scope. Work log: `08-memory/long-term/mpos-lib-migration-20260222.md`

**Why:** Full BNPRS fintech card stack — ICBA biometric smart card issuance and verification product, plus R&D documentation.

**How to apply:** When user references Qi card, EMV, card personalisation, APDU, PC/SC, ICBA, BRUID, BIX applet, or fintech R&D — point to na-005 agents. Source repos: `/Users/bnprs/BPR/GitRepos1/bpr.cpp/src/`, `/Users/bnprs/BPR/GitRepos1/bpr.bix`, `/Users/bnprs/BPR/GitRepos1/bpr.rnd`.
