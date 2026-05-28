# na-009-bnprs-products — BNPRS Product Agents

One agent per product. Each agent defines the product's rules, workflows, connectors, and memory.

## Product Catalogue

Agent codes 001–011 align with product code suffix (BPR100X → 00X).

| Agent Code | Product Code | Product Name     | Notes                                    |
|------------|--------------|------------------|------------------------------------------|
| 001        | BPR1001      | iBecs            | Instant Biometric Enrollment Card Solution|
| 002        | BPR1002      | mGate            | API/Mobile Gateway                       |
| 003        | BPR1003      | mPos             | Mobile Point of Sale (PatPOS)            |
| 004        | BPR1004      | uTms             | Unified Terminal Management System       |
| 005        | BPR1005      | bPass (icba)     | Issuer Controlled Biometric Auth         |
| 006        | BPR1006      | patKiosk         | Self-Service Kiosk Platform              |
| 007        | BPR1007      | wGate            | Worldwide Gateway for Payment Processing |
| 008        | BPR1008      | bNet             | Biometric Network                        |
| 009        | BPR1009      | bCws             | Biometric Criminal Watch System          |
| 010        | BPR1010      | Misc-ITP         | Miscellaneous ITPCore Projects           |
| 011        | BPR1011      | DrishtIQ         | Reputation Management System             |
| 012        | BPR0000      | BNPRS Portal     | Web-Based Enterprise Portal (HR, Payroll, Sprints, Expenses, Codebase) |
| 013        | BPR1000      | uTms-CRM         | License Management, Clients, Subscriptions|
| 014        | TRP1001      | SbioidS          | SBI Biometric Identification System      |
| (pending)  | TRP1002      | cPerso           | Central Personalisation                  |
| (pending)  | TRP1003      | pHsm             |                                          |
| (pending)  | TRP1004      | BNAgent          | AI Agent Platform (aim.pat)              |
| (pending)  | TRP1006      | eInvoice         |                                          |
| (pending)  | BPR2001      | AandhiPe         | Super-App                                |
| (pending)  | AIM1001      | AIM Team         |                                          |
| (pending)  | AIM1002      | bIOI             |                                          |

## Agent Naming Convention

Agent names follow the pattern `<product-code>-<product-slug>`, e.g.:

```
001-bpr1001-ibecs/
002-bpr1002-mgate/
003-bpr1003-mpos/
```

## Agents Created

- `001-bpr1001-ibecs/` — BPR1001 iBecs product agent
- `002-bpr1002-mgate/` — BPR1002 mGate API/Mobile Gateway product agent
- `003-bpr1003-mpos/` — BPR1003 mPos Mobile Point of Sale / PatPOS product agent
- `004-bpr1004-utms/` — BPR1004 uTms Unified Transaction Management System product agent
- `005-bpr1005-bpass/` — BPR1005 bPass Issuer Controlled Biometric Authentication (ICBA) product agent
- `006-bpr1006-patkiosk/` — BPR1006 patKiosk Self-Service Kiosk Platform product agent
- `007-bpr1007-wgate/` — BPR1007 wGate Worldwide Gateway for Payment Processing product agent
- `008-bpr1008-bnet/` — BPR1008 bNet Biometric Network product agent
- `009-bpr1009-bcws/` — BPR1009 bCws Biometric Criminal Watch System product agent
- `010-bpr1010-misc-itp/` — BPR1010 Misc-ITP Miscellaneous ITPCore Projects product agent
- `011-bpr1011-drishtiq/` — BPR1011 DrishtIQ Reputation Management System product agent
- `012-bpr0000-bnprs-portal/` — BPR0000 BNPRS Portal Web-Based Enterprise Portal product agent
- `013-bpr1000-utms-crm/` — BPR1000 uTms-CRM License Management, Clients, Subscriptions product agent
- `014-trp1001-sbioids/` — TRP1001 SbioidS SBI Biometric Identification System product agent
