---
name: project-na006-agents
description: "na-006-bnprs-deployments: 7 active agents (001–007) covering production deployments of all major BNPRS products and TRP projects"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cd3a02c-667d-4ad2-a5bb-49b30d3c7376
---

na-006-bnprs-deployments has 7 active agents (codes 001–007), all created 2026-05-27:

- 001 bpr1002-mgate-prod — BPR M-Gate: API/Mobile Gateway production deployment; routes traffic to ICBA, BRUID, BprIDEngine backends
- 002 bpr1004-utms-prod — BPR UTMS: Unified Transaction Management System; central engine for biometric-authenticated financial transactions; includes DB migration management
- 003 bpr1000-license-prod — BPR License Server: software license issuance/validation for all BNPRS products (BprIDEngine, ICBA, ACS); KMS alias for signing key; critical uptime dependency
- 004 trp1001-sbioids-prod — TRP SBIO IDS: SBI (State Bank of India) biometric identification system deployment; customer on-premise; BprIDEngine (face + finger) bundled
- 005 bpr1005-icba-prod — BPR ICBA: Issuer Controlled Biometric Authentication full platform; multi-component (server + terminal APK/installer + KMS fleet cert); applet version compatibility matrix
- 006 trp1004-nagents-prod — TRP nagents: aim.pat AI agent platform itself; EC2 aim1001-bnprs-claude (ITPCore/us-east-2); GitHub ramaiahsvn/aim.pat; AWS profile itp
- 007 bpr1007-acs-prod — BPR ACS: Access Control System; biometric (face/finger/iris) + hardware (door controllers, turnstiles); on-premise customer sites; biometric enrollment DB backup before every deploy

**Naming convention:** `bpr` = BNPRS internal product, `trp` = turnkey/third-party release project; 4-digit product number; `-prod` = production environment.

**Why:** Production deployment agents for the full BNPRS product portfolio.

**How to apply:** When user references deploying, releasing, or managing production for any BNPRS product — point to na-006. Each agent owns one product's production lifecycle.
