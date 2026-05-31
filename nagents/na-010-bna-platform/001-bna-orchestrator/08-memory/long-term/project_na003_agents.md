---
name: project-na003-agents
description: "na-003-bnprs-infra: 8 active agents — latest are 007 bnprs-grc-kms and 008 bnprs-grc (created 2026-05-27)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cd3a02c-667d-4ad2-a5bb-49b30d3c7376
---

na-003-bnprs-infra has 8 active agents (codes 001–008):

- 007 bnprs-grc-kms — HSM Key Management (kms.bnprs.ai, alias/qi-supervisor-key, ap-south-2)
- 008 bnprs-grc — Governance, Risk, and Compliance (bpr.grc: bpr.usb, bpr.pci, bpr.kms)

**Why:** Both created 2026-05-27 from bpr.grc work. 008 depends on 007 for key ops.

**How to apply:** When user references GRC, PCI-DSS, USB controls, or kms.bnprs.ai — the relevant agents are 008-bnprs-grc and 007-bnprs-grc-kms in na-003. Source repo is `/Users/bnprs/BPR/GitRepos1/bpr.grc`.
