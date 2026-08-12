---
name: project-na009-agents
description: "na-009-bnprs-products group — 21 BNPRS product agents, one per product line"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1181ad69-93b2-4573-b7cf-8f65ab34be80
---

Group `na-009-bnprs-products` created 2026-05-28. 21/255 slots used. Next available code: 022.

Codes 001–011 align with BPR100X suffix (BPR1001→001 ... BPR1011→011).

| Code | Name | Product Code | Description |
|------|------|--------------|-------------|
| 001  | bpr1001-ibecs | BPR1001 | Instant Biometric Enrollment Card Solution |
| 002  | bpr1002-mgate | BPR1002 | API and Mobile Gateway |
| 003  | bpr1003-mpos | BPR1003 | Mobile Point of Sale / PatPOS |
| 004  | bpr1004-utms | BPR1004 | Unified Terminal Management System |
| 005  | bpr1005-bpass | BPR1005 | Issuer Controlled Biometric Authentication (ICBA) |
| 006  | bpr1006-patkiosk | BPR1006 | Self-Service Kiosk Platform |
| 007  | bpr1007-wgate | BPR1007 | Worldwide Gateway for Payment Processing |
| 008  | bpr1008-bnet | BPR1008 | Biometric Network |
| 009  | bpr1009-bcws | BPR1009 | Biometric Criminal Watch System |
| 010  | bpr1010-misc-itp | BPR1010 | Miscellaneous ITPCore Projects |
| 011  | bpr1011-drishtiq | BPR1011 | Reputation Management System (DrishtIQ) |
| 012  | bpr0000-bnprs-portal | BPR0000 | Web-Based Enterprise Portal (HR, Payroll, Sprints, Expenses, Codebase) |
| 013  | bpr1000-utms-crm | BPR1000 | License Management, Clients, Subscriptions |
| 014  | trp1001-sbioids | TRP1001 | SBI Biometric Identification System |
| 015  | trp1002-cperso | TRP1002 | Card Personalization (Instant and Central) |
| 016  | bpr2002-talabqi | BPR2002 | QiTalab food-ordering platform (code re-used 2026-08-12) |
| 017  | trp1004-bnagent | TRP1004 | AI Agent Platform (aim.pat) |
| 018  | trp1005-einvoice | TRP1005 | Electronic Invoice Management |

> **Code 016 was re-used on 2026-08-12.** It was `trp1003-phsm`; that agent's pHSM work — the
> Functionality Module, its seven tasks, its DNA (FM build rules, branch policy, signing material, the
> hard-won cautions, the CAVV precedent checklist) and its long-term memory — was transferred to
> `na-005/013 bruid-kms-phsm`, and 016 was then reassigned to `bpr2002-talabqi`. This is an
> owner-authorised exception to the permanent-code rule; the precedent is 011 on 2026-07-16.
> **Do not route pHSM or FM work to 016 — it goes to na-005/013.**
>
> `016 bpr2002-talabqi` — QiTalab, a food-ordering platform. GitLab group `BPR2002 - QiTalab`
> (id 309, private, created 2026-07-28) with six projects: customer mini-app (251), courier mini-app
> (252), restaurant POS Android (253), merchant portal (254), ops console (255), backend API (256).
> No local checkout recorded and **scope not yet defined** — ask before routing work. Naming: GitLab
> says *QiTalab*, the agent is named *talabqi* per owner instruction.
| 019  | bpr2001-aandhipe | BPR2001 | Super-App |
| 020  | aim1001-aim-team | AIM1001 | AI Agent Platform Team |
| 021  | aim1002-bioi | AIM1002 | Biometric Intelligence |

**Why:** Dedicated group for product-specific agents, separate from na-006 (deployments) and na-002 (core ops). Full catalogue in `nagents/na-009-bnprs-products/README.md`.

**How to apply:** When creating a new product agent, use na-009, next code 022. For product descriptions and acronyms, refer to the table above.
