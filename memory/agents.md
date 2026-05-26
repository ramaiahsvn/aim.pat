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
| 001  | na-006 | bpr1002-mgate-prod | BPR M-Gate Production (API/Mobile Gateway) | active | 2026-05-27 |
| 002  | na-006 | bpr1004-utms-prod | BPR UTMS Production (Unified Transaction Management System) | active | 2026-05-27 |
| 003  | na-006 | bpr1000-license-prod | BPR License Server Production | active | 2026-05-27 |
| 004  | na-006 | trp1001-sbioids-prod | TRP SBI Biometric IDS Production | active | 2026-05-27 |
| 005  | na-006 | bpr1005-icba-prod | BPR ICBA Production (Issuer Controlled Biometric Authentication) | active | 2026-05-27 |
| 006  | na-006 | trp1004-nagents-prod | TRP nagents AI Agent Platform Production (aim.pat) | active | 2026-05-27 |
| 007  | na-006 | bpr1007-acs-prod | BPR ACS Production (Access Control System) | active | 2026-05-27 |

## Group Slot Usage

| Group | ID | Used | Max |
|-------|----|------|-----|
| na-001-personal          | na-001 | 6  | 255 |
| na-002-bnprs-core        | na-002 | 10 | 255 |
| na-003-bnprs-infra       | na-003 | 8  | 255 |
| na-004-bnprs-biometrics  | na-004 | 12 | 255 |
| na-005-bnprs-fintech     | na-005 | 11 | 255 |
| na-006-bnprs-deployments | na-006 | 7  | 255 |
| na-007-bnprs-team        | na-007 | 0  | 255 |

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
