---
name: project-na008-agents
description: "na-008-bnprs-team: 100 Kaurava employee agents (AID-001–100); GitLab repos renamed aim1001.aid.001–100 (were aim1001.aim.NNN)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d20ff47-3cf9-442e-ae4c-cc024cc3e7ba
---

na-008-bnprs-team holds 100 employee Agent IDs (AID-001 to AID-100), named after the 100 Kauravas.

## GitLab Repos (aim1001 group)

- **Pattern**: `aim1001.aid.NNN`  (renamed 2026-05-28 from `aim1001.aim.NNN`)
- **Remote**: `https://gitlab.bnprs.ai/aim1001/aim1001.aid.NNN`
- **Local clone**: `/Users/bnprs/BPR/GitRepos2/AIM1001_Team/aim1001.aid.NNN/`
- **GitLab IDs**: 128–227
- **Branch**: `master` only
- **Structure**: `CLAUDE.md`, `agent.yaml`, `08-memory/` (short-term, long-term, learned-preferences)

## Session Manager

Session IDs use format `E<EID>-aid.<NNN>` (e.g. `E1026-aid.001`).  
Script: `nagents/na-003-bnprs-infra/006-bnprs-claude/03-nucleus/bnprs-sessions.sh`  
Maps `aid.NNN` → `aim1001.aid.NNN` repo automatically.

**Why:** Renamed to align session ID format (`E1026-aid.001`) with repo naming (`aim1001.aid.001`). Old name `aim1001.aim.NNN` was inconsistent.

**How to apply:** When referencing employee agent repos, use `aim1001.aid.NNN`. [[project-bnprs-claude-vpn]]
