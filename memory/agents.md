# Agents Memory — aim.pat

> Cross-agent context: active agents, relationships, and inter-agent dependencies.
> Updated automatically when agents are created, retired, or linked.

## Active Agents

| Code | Group  | Name | Role | Status | Created |
|------|--------|------|------|--------|---------|
| 001  | na-001 | pat-emails-todo | Email and Task Manager | active | 2026-05-26 |
| 002  | na-001 | pat-fbmi | Family Health & Nutrition Assistant | active | 2026-05-26 |
| 003  | na-001 | pat-mfin | Personal Finance Manager | active | 2026-05-26 |
| 004  | na-001 | pat-fhbs | Home Balance Sheet | active | 2026-05-26 |
| 005  | na-001 | pat-assets | Personal Asset Manager | active | 2026-05-26 |
| 006  | na-001 | pat-patents | Patents and IP Manager | active | 2026-05-26 |
| 001  | na-002 | bnprs-chat | Messaging and Communications Manager | active | 2026-05-26 |
| 002  | na-002 | bnprs-admin | Admin, HR, Legal and Compliance | active | 2026-05-26 |
| 003  | na-002 | bnprs-finance | Business Finance, Accounting, Tax | active | 2026-05-26 |
| 004  | na-002 | bnprs-sales | Sales, Marketing and Customer | active | 2026-05-26 |
| 005  | na-002 | bnprs-websites | Website and Digital Presence | active | 2026-05-26 |
| 006  | na-002 | bnprs-social-media | Social Media and Content | active | 2026-05-26 |
| 007  | na-002 | bnprs-docs | Business Documents and Templates | active | 2026-05-26 |
| 008  | na-002 | bnprs-tech-docs | Technical Products Documentation | active | 2026-05-26 |
| 009  | na-002 | bnprs-presentations | Presentations and Pitch Decks | active | 2026-05-26 |
| 010  | na-002 | bnprs-certifications | ISO, PCI-DSS, CMMI Certifications | active | 2026-05-26 |
| 001  | na-003 | bnprs-aws | BNPRS AWS Account Manager (891963159778, ap-south-2) | active | 2026-05-26 |
| 002  | na-003 | bnprs-aws-itp | ITPCore AWS Account Manager (819144294008, us-east-2) | active | 2026-05-26 |
| 003  | na-003 | bnprs-gitlab | Self-Hosted GitLab Manager (gitlab.bnprs.ai, CE 18.9.0) | active | 2026-05-26 |
| 004  | na-003 | bnprs-github | GitHub Accounts Manager (ramaiahsvn, ramaiahsvn2, iCodeScrum) | active | 2026-05-26 |
| 005  | na-003 | bnprs-websites | Website Infrastructure Manager (bnprs.ai/in/com, aandhipe.in) | active | 2026-05-26 |
| 006  | na-003 | bnprs-claude | AI Model Subscription Instance (EC2: aim1001-bnprs-claude) | active | 2026-05-26 |
| 007  | na-003 | bnprs-grc-kms | HSM Key Management System (kms.bnprs.ai, alias/qi-supervisor-key) | active | 2026-05-26 |
| 008  | na-003 | bnprs-grc | Governance, Risk, and Compliance (bpr.grc: bpr.usb, bpr.pci, bpr.kms) | active | 2026-05-27 |
| 001  | na-004 | cpp-face | BprFace C++ Module (face detection, recognition, expression, action) | active | 2026-05-27 |
| 002  | na-004 | cpp-finger | BprFinger C++ Module (Fjfx, Forg, M3gl, Nbis, Nfiq2, Nnmq) | active | 2026-05-27 |
| 003  | na-004 | cpp-finger-cless | BprFingerCless C++ Module (contactless fingerprint preprocessing) | active | 2026-05-27 |
| 004  | na-004 | cpp-finger-knuckle | BprFingerKnuckle C++ Module (L4/R4/T2 segmentation + matching) | active | 2026-05-27 |
| 005  | na-004 | cpp-palmprint | BprPalmprint C++ Module (not yet implemented) | active | 2026-05-27 |
| 006  | na-004 | cpp-iris | BprIris C++ Module (Masek + VASIR iris recognition) | active | 2026-05-27 |
| 007  | na-004 | cpp-dna | BprDNA C++ Module (not yet implemented) | active | 2026-05-27 |
| 008  | na-004 | cpp-sheep | BprSheep C++ Module (livestock biometrics, not yet implemented) | active | 2026-05-27 |
| 009  | na-004 | cpp-video | BprVideo C++ Module (video biometrics, not yet implemented) | active | 2026-05-27 |
| 010  | na-004 | algo-certify | Algorithm Certification and Benchmarking (all modalities) | active | 2026-05-27 |
| 011  | na-004 | rnd-biometrics | Biometrics Research and Development | active | 2026-05-27 |
| 012  | na-004 | rnd-evaluations | Biometric Algorithm Evaluations (DET, EER, FMR/FNMR) | active | 2026-05-27 |
| 001  | na-005 | cpp-icba-all | Issuer Controlled Biometric Authentication (ICBA orchestrator) | active | 2026-05-27 |
| 002  | na-005 | cpp-card-qi | BprCardQi — Qi smart card I/O, biometric data read, fleet cert (kms.bnprs.ai) | active | 2026-05-27 |
| 003  | na-005 | cpp-card-emv | BprCardEmv — EMV smart card, AID selection, PureScript APDU | active | 2026-05-27 |
| 004  | na-005 | cpp-card-pure | BprScripts — QiScript (perso/reset/read) + PureScript (EMV APDU) | active | 2026-05-27 |
| 005  | na-005 | cpp-pcsc-all | BprPcSc — cross-platform PC/SC (Windows/Linux/Android 8 vendors, TP9000, TTC) | active | 2026-05-27 |
| 006  | na-005 | k3-bix-applet | BIX JavaCard applet v2.55.2 (biometric storage on chip, IP transferred to Menta) | active | 2026-05-27 |
| 007  | na-005 | bruid-applet | BRUID JavaCard applet (Patent-3 India, BNPRS-owned) | active | 2026-05-27 |
| 008  | na-005 | bruid-dprep | BRUID Data Preparation (74-field central blob / 52-field instant hex) | active | 2026-05-27 |
| 009  | na-005 | bruid-cperso | BRUID Central Personalization (bureau batch, HSM, BprQiEmv DLL) | active | 2026-05-27 |
| 010  | na-005 | bruid-iperso | BRUID Instant Issuance Solution (branch counter, remote kms.bnprs.ai auth) | active | 2026-05-27 |
| 011  | na-005 | rnd-fintech | Fintech Research and Development (EMV, DUKPT, CPS, BRUID, biometric templates) | active | 2026-05-27 |
| 012  | na-005 | bpr1003-mpos-libs-usage | BPR1003 mPOS C++ Libraries (PatPOS client-side libraries for mobile point-of-sale) | active | 2026-05-28 |
| 001  | na-006 | bpr1002-mgate-prod | BPR M-Gate Production (API/Mobile Gateway) | active | 2026-05-27 |
| 002  | na-006 | bpr1004-utms-prod | BPR UTMS Production (Unified Transaction Management System) | active | 2026-05-27 |
| 003  | na-006 | bpr1000-license-prod | BPR License Server Production | active | 2026-05-27 |
| 004  | na-006 | trp1001-sbioids-prod | TRP SBI Biometric IDS Production | active | 2026-05-27 |
| 005  | na-006 | bpr1005-icba-prod | BPR ICBA Production (Issuer Controlled Biometric Authentication) | active | 2026-05-27 |
| 006  | na-006 | trp1004-nagents-prod | TRP nagents AI Agent Platform Production (aim.pat) | active | 2026-05-27 |
| 007  | na-006 | bpr1007-acs-prod | BPR ACS Production (Access Control System) | active | 2026-05-27 |
| 001  | na-100 | rnd-mpos | mPOS R&D and Competitive Analysis (BPR1003 PatPOS, PhonePe ref) | active | 2026-05-27 |
| 002  | na-100 | rnd-superapp | AandhiPe Super-App R&D (BPR2001, SuperQi/WeChat/ONDC ref) | active | 2026-05-27 |
| 001  | na-009 | bpr1002-mgate | BPR mGate Product Agent — API and Mobile Gateway (BPR1002) | active | 2026-05-28 |
| 001  | na-007 | aid-ceo (Yudhisthira) | Chief Executive Officer — strategy, vision, governance | active | 2026-05-27 |
| 002  | na-007 | aid-cto (Bhima)       | Chief Technology Officer — tech strategy, engineering, platform | active | 2026-05-27 |
| 003  | na-007 | aid-cpo (Arjuna)      | Chief Product Officer — product strategy, roadmap, UX/CX | active | 2026-05-27 |
| 004  | na-007 | aid-cfo (Nakula)      | Chief Financial Officer — finance, treasury, compliance | active | 2026-05-27 |
| 005  | na-007 | aid-coo (Sahadeva)    | Chief Operating Officer — operations, delivery, process | active | 2026-05-27 |
| 001  | na-008 | aid-duryodhana | BNPRS Team Member (Kaurava AID-001) | active | 2026-05-27 |
| 002  | na-008 | aid-dushasana | BNPRS Team Member (Kaurava AID-002) | active | 2026-05-27 |
| 003  | na-008 | aid-dussaha | BNPRS Team Member (Kaurava AID-003) | active | 2026-05-27 |
| 004  | na-008 | aid-dussala | BNPRS Team Member (Kaurava AID-004) | active | 2026-05-27 |
| 005  | na-008 | aid-jalasandha | BNPRS Team Member (Kaurava AID-005) | active | 2026-05-27 |
| 006  | na-008 | aid-sama | BNPRS Team Member (Kaurava AID-006) | active | 2026-05-27 |
| 007  | na-008 | aid-saha | BNPRS Team Member (Kaurava AID-007) | active | 2026-05-27 |
| 008  | na-008 | aid-vinda | BNPRS Team Member (Kaurava AID-008) | active | 2026-05-27 |
| 009  | na-008 | aid-anuvinda | BNPRS Team Member (Kaurava AID-009) | active | 2026-05-27 |
| 010  | na-008 | aid-durdharsha | BNPRS Team Member (Kaurava AID-010) | active | 2026-05-27 |
| 011  | na-008 | aid-subahu | BNPRS Team Member (Kaurava AID-011) | active | 2026-05-27 |
| 012  | na-008 | aid-dushpradharshana | BNPRS Team Member (Kaurava AID-012) | active | 2026-05-27 |
| 013  | na-008 | aid-durmarshana | BNPRS Team Member (Kaurava AID-013) | active | 2026-05-27 |
| 014  | na-008 | aid-durmukha | BNPRS Team Member (Kaurava AID-014) | active | 2026-05-27 |
| 015  | na-008 | aid-dushkarna | BNPRS Team Member (Kaurava AID-015) | active | 2026-05-27 |
| 016  | na-008 | aid-karna | BNPRS Team Member (Kaurava AID-016) | active | 2026-05-27 |
| 017  | na-008 | aid-vivimsati | BNPRS Team Member (Kaurava AID-017) | active | 2026-05-27 |
| 018  | na-008 | aid-vikarna | BNPRS Team Member (Kaurava AID-018) | active | 2026-05-27 |
| 019  | na-008 | aid-shala | BNPRS Team Member (Kaurava AID-019) | active | 2026-05-27 |
| 020  | na-008 | aid-satva | BNPRS Team Member (Kaurava AID-020) | active | 2026-05-27 |
| 021  | na-008 | aid-sulochana | BNPRS Team Member (Kaurava AID-021) | active | 2026-05-27 |
| 022  | na-008 | aid-chitra | BNPRS Team Member (Kaurava AID-022) | active | 2026-05-27 |
| 023  | na-008 | aid-upachitra | BNPRS Team Member (Kaurava AID-023) | active | 2026-05-27 |
| 024  | na-008 | aid-chitraksha | BNPRS Team Member (Kaurava AID-024) | active | 2026-05-27 |
| 025  | na-008 | aid-charuchitra | BNPRS Team Member (Kaurava AID-025) | active | 2026-05-27 |
| 026  | na-008 | aid-sarasana | BNPRS Team Member (Kaurava AID-026) | active | 2026-05-27 |
| 027  | na-008 | aid-durmada | BNPRS Team Member (Kaurava AID-027) | active | 2026-05-27 |
| 028  | na-008 | aid-durvigaha | BNPRS Team Member (Kaurava AID-028) | active | 2026-05-27 |
| 029  | na-008 | aid-vivitsu | BNPRS Team Member (Kaurava AID-029) | active | 2026-05-27 |
| 030  | na-008 | aid-vikatanana | BNPRS Team Member (Kaurava AID-030) | active | 2026-05-27 |
| 031  | na-008 | aid-urnanabha | BNPRS Team Member (Kaurava AID-031) | active | 2026-05-27 |
| 032  | na-008 | aid-sunabha | BNPRS Team Member (Kaurava AID-032) | active | 2026-05-27 |
| 033  | na-008 | aid-nanda | BNPRS Team Member (Kaurava AID-033) | active | 2026-05-27 |
| 034  | na-008 | aid-upananda | BNPRS Team Member (Kaurava AID-034) | active | 2026-05-27 |
| 035  | na-008 | aid-chitrabana | BNPRS Team Member (Kaurava AID-035) | active | 2026-05-27 |
| 036  | na-008 | aid-chitravarma | BNPRS Team Member (Kaurava AID-036) | active | 2026-05-27 |
| 037  | na-008 | aid-suvarma | BNPRS Team Member (Kaurava AID-037) | active | 2026-05-27 |
| 038  | na-008 | aid-durvimochana | BNPRS Team Member (Kaurava AID-038) | active | 2026-05-27 |
| 039  | na-008 | aid-ayobahu | BNPRS Team Member (Kaurava AID-039) | active | 2026-05-27 |
| 040  | na-008 | aid-mahabahu | BNPRS Team Member (Kaurava AID-040) | active | 2026-05-27 |
| 041  | na-008 | aid-chitranga | BNPRS Team Member (Kaurava AID-041) | active | 2026-05-27 |
| 042  | na-008 | aid-chitrakundala | BNPRS Team Member (Kaurava AID-042) | active | 2026-05-27 |
| 043  | na-008 | aid-bhimavega | BNPRS Team Member (Kaurava AID-043) | active | 2026-05-27 |
| 044  | na-008 | aid-bhimabala | BNPRS Team Member (Kaurava AID-044) | active | 2026-05-27 |
| 045  | na-008 | aid-balaki | BNPRS Team Member (Kaurava AID-045) | active | 2026-05-27 |
| 046  | na-008 | aid-balavardhana | BNPRS Team Member (Kaurava AID-046) | active | 2026-05-27 |
| 047  | na-008 | aid-ugrayudha | BNPRS Team Member (Kaurava AID-047) | active | 2026-05-27 |
| 048  | na-008 | aid-sushena | BNPRS Team Member (Kaurava AID-048) | active | 2026-05-27 |
| 049  | na-008 | aid-kundadhara | BNPRS Team Member (Kaurava AID-049) | active | 2026-05-27 |
| 050  | na-008 | aid-mahodara | BNPRS Team Member (Kaurava AID-050) | active | 2026-05-27 |
| 051  | na-008 | aid-chitrayudha | BNPRS Team Member (Kaurava AID-051) | active | 2026-05-27 |
| 052  | na-008 | aid-nishangi | BNPRS Team Member (Kaurava AID-052) | active | 2026-05-27 |
| 053  | na-008 | aid-pashi | BNPRS Team Member (Kaurava AID-053) | active | 2026-05-27 |
| 054  | na-008 | aid-vrindaraka | BNPRS Team Member (Kaurava AID-054) | active | 2026-05-27 |
| 055  | na-008 | aid-dridhavarma | BNPRS Team Member (Kaurava AID-055) | active | 2026-05-27 |
| 056  | na-008 | aid-dridhakshatra | BNPRS Team Member (Kaurava AID-056) | active | 2026-05-27 |
| 057  | na-008 | aid-somakirti | BNPRS Team Member (Kaurava AID-057) | active | 2026-05-27 |
| 058  | na-008 | aid-anudara | BNPRS Team Member (Kaurava AID-058) | active | 2026-05-27 |
| 059  | na-008 | aid-dridhasandha | BNPRS Team Member (Kaurava AID-059) | active | 2026-05-27 |
| 060  | na-008 | aid-jarasandha | BNPRS Team Member (Kaurava AID-060) | active | 2026-05-27 |
| 061  | na-008 | aid-satyasandha | BNPRS Team Member (Kaurava AID-061) | active | 2026-05-27 |
| 062  | na-008 | aid-sadasuvak | BNPRS Team Member (Kaurava AID-062) | active | 2026-05-27 |
| 063  | na-008 | aid-ugrashravas | BNPRS Team Member (Kaurava AID-063) | active | 2026-05-27 |
| 064  | na-008 | aid-ugrasena | BNPRS Team Member (Kaurava AID-064) | active | 2026-05-27 |
| 065  | na-008 | aid-senani | BNPRS Team Member (Kaurava AID-065) | active | 2026-05-27 |
| 066  | na-008 | aid-dushparajaya | BNPRS Team Member (Kaurava AID-066) | active | 2026-05-27 |
| 067  | na-008 | aid-aparajita | BNPRS Team Member (Kaurava AID-067) | active | 2026-05-27 |
| 068  | na-008 | aid-kundashayi | BNPRS Team Member (Kaurava AID-068) | active | 2026-05-27 |
| 069  | na-008 | aid-vishalaksha | BNPRS Team Member (Kaurava AID-069) | active | 2026-05-27 |
| 070  | na-008 | aid-duradhara | BNPRS Team Member (Kaurava AID-070) | active | 2026-05-27 |
| 071  | na-008 | aid-dridhahasta | BNPRS Team Member (Kaurava AID-071) | active | 2026-05-27 |
| 072  | na-008 | aid-suhasta | BNPRS Team Member (Kaurava AID-072) | active | 2026-05-27 |
| 073  | na-008 | aid-vatavega | BNPRS Team Member (Kaurava AID-073) | active | 2026-05-27 |
| 074  | na-008 | aid-suvarchas | BNPRS Team Member (Kaurava AID-074) | active | 2026-05-27 |
| 075  | na-008 | aid-adityaketu | BNPRS Team Member (Kaurava AID-075) | active | 2026-05-27 |
| 076  | na-008 | aid-bahvashi | BNPRS Team Member (Kaurava AID-076) | active | 2026-05-27 |
| 077  | na-008 | aid-nagadatta | BNPRS Team Member (Kaurava AID-077) | active | 2026-05-27 |
| 078  | na-008 | aid-anuyayi | BNPRS Team Member (Kaurava AID-078) | active | 2026-05-27 |
| 079  | na-008 | aid-kavachi | BNPRS Team Member (Kaurava AID-079) | active | 2026-05-27 |
| 080  | na-008 | aid-nishangi | BNPRS Team Member (Kaurava AID-080) | active | 2026-05-27 |
| 081  | na-008 | aid-dandi | BNPRS Team Member (Kaurava AID-081) | active | 2026-05-27 |
| 082  | na-008 | aid-dandadhara | BNPRS Team Member (Kaurava AID-082) | active | 2026-05-27 |
| 083  | na-008 | aid-dhanurgraha | BNPRS Team Member (Kaurava AID-083) | active | 2026-05-27 |
| 084  | na-008 | aid-ugra | BNPRS Team Member (Kaurava AID-084) | active | 2026-05-27 |
| 085  | na-008 | aid-bhimaratha | BNPRS Team Member (Kaurava AID-085) | active | 2026-05-27 |
| 086  | na-008 | aid-vira | BNPRS Team Member (Kaurava AID-086) | active | 2026-05-27 |
| 087  | na-008 | aid-virabahu | BNPRS Team Member (Kaurava AID-087) | active | 2026-05-27 |
| 088  | na-008 | aid-alolupa | BNPRS Team Member (Kaurava AID-088) | active | 2026-05-27 |
| 089  | na-008 | aid-abhaya | BNPRS Team Member (Kaurava AID-089) | active | 2026-05-27 |
| 090  | na-008 | aid-raudrakarma | BNPRS Team Member (Kaurava AID-090) | active | 2026-05-27 |
| 091  | na-008 | aid-dridharatha | BNPRS Team Member (Kaurava AID-091) | active | 2026-05-27 |
| 092  | na-008 | aid-anadhrishya | BNPRS Team Member (Kaurava AID-092) | active | 2026-05-27 |
| 093  | na-008 | aid-kundabhedi | BNPRS Team Member (Kaurava AID-093) | active | 2026-05-27 |
| 094  | na-008 | aid-viravi | BNPRS Team Member (Kaurava AID-094) | active | 2026-05-27 |
| 095  | na-008 | aid-dhirghalochana | BNPRS Team Member (Kaurava AID-095) | active | 2026-05-27 |
| 096  | na-008 | aid-pramatha | BNPRS Team Member (Kaurava AID-096) | active | 2026-05-27 |
| 097  | na-008 | aid-pramathi | BNPRS Team Member (Kaurava AID-097) | active | 2026-05-27 |
| 098  | na-008 | aid-dirghabahu | BNPRS Team Member (Kaurava AID-098) | active | 2026-05-27 |
| 099  | na-008 | aid-suvirya | BNPRS Team Member (Kaurava AID-099) | active | 2026-05-27 |
| 100  | na-008 | aid-dirghatama | BNPRS Team Member (Kaurava AID-100) | active | 2026-05-27 |

## Group Slot Usage

| Group | ID | Used | Max |
|-------|----|------|-----|
| na-001-personal          | na-001 | 6  | 255 |
| na-002-bnprs-core        | na-002 | 10 | 255 |
| na-003-bnprs-infra       | na-003 | 8  | 255 |
| na-004-bnprs-biometrics  | na-004 | 12 | 255 |
| na-005-bnprs-fintech     | na-005 | 12 | 255 |
| na-006-bnprs-deployments | na-006 | 7  | 255 |
| na-007-bnprs-cxo         | na-007 | 5  | 255 |
| na-008-bnprs-team        | na-008 | 100 | 255 |
| na-009-bnprs-products    | na-009 | 1  | 255 |
| na-100-gne-esrever       | na-100 | 2  | 255 |

## Inter-Agent Dependencies

| Agent | Depends On | Reason |
|-------|-----------|--------|
| na-003/005 bnprs-websites | na-003/001 bnprs-aws | AWS credentials (profile bnprs) for S3 sync and CloudFront invalidation |
| na-003/006 bnprs-claude | na-003/002 bnprs-aws-itp | Escalate instance-level issues (restart, resize, SG, billing) to ITP AWS agent |
| na-003/008 bnprs-grc | na-003/007 bnprs-grc-kms | Key rotation, cert renewals, Lambda IAM policy for bpr.kms/k3-verifychallenge |
| na-003/008 bnprs-grc | na-003/001 bnprs-aws | AWS account context for bpr.kms infrastructure (ap-south-2) |

## Notes

- 01 pat-emails-todo nucleus fully defined — Gmail, Outlook, Zoho Mail; triage, draft replies, extract tasks, summarise threads; priority by category (business/legal/finance > personal > marketing)
- 02 pat-fbmi nucleus (`03-nucleus/CLAUDE.md`) is a template shell — family health, nutrition, doctor advice domain not yet filled in
- 03 pat-mfin nucleus (`03-nucleus/CLAUDE.md`) is a template shell — personal finance, income, expenses domain not yet filled in
- 04 pat-fhbs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — household expenses, family balance sheet domain not yet filled in
- 05 pat-assets nucleus (`03-nucleus/CLAUDE.md`) is a template shell — lands, flats, properties, real estate portfolio domain not yet filled in
- 06 pat-patents nucleus (`03-nucleus/CLAUDE.md`) is a template shell — patents, trademarks, copyrights, IP portfolio domain not yet filled in
- na-002/01 bnprs-leadership nucleus (`03-nucleus/CLAUDE.md`) is a template shell — CEO/CTO vision, strategy, certifications domain not yet filled in
- na-002/02 bnprs-admin nucleus (`03-nucleus/CLAUDE.md`) is a template shell — admin, HR, legal, compliance domain not yet filled in
- na-002/03 bnprs-finance nucleus (`03-nucleus/CLAUDE.md`) is a template shell — business finance, accounting, tax domain not yet filled in
- na-002/04 bnprs-sales nucleus (`03-nucleus/CLAUDE.md`) is a template shell — sales, marketing, customer relations domain not yet filled in
- na-002/05 bnprs-websites nucleus (`03-nucleus/CLAUDE.md`) is a template shell — bnprs.ai, bnprs.in, bnprs.com web presence domain not yet filled in
- na-002/06 bnprs-social-media nucleus (`03-nucleus/CLAUDE.md`) is a template shell — LinkedIn, Twitter, Instagram, YouTube, podcasts domain not yet filled in
- na-002/07 bnprs-docs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — offer letters, NDAs, appointment letters, contracts domain not yet filled in
- na-002/08 bnprs-tech-docs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — technical specs, product docs, API docs, user manuals domain not yet filled in
- na-002/09 bnprs-presentations nucleus (`03-nucleus/CLAUDE.md`) is a template shell — corporate PPT, pitch decks, investor presentations domain not yet filled in
