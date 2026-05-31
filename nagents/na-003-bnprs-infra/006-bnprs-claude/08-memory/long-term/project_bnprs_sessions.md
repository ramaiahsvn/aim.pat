---
name: project-bnprs-sessions
description: "bnprs-sessions.sh session manager — AID notation, /srv/aim1001 on EC2, info_bnprs, tier subgroups"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3e957bc2-5476-47e3-80bf-6ee8098cda91
---

The **bnprs-claude** session manager (`bnprs-sessions.sh`, na-003/006) was overhauled
2026-05-30 from the old `E####` (employee-id) scheme to **AID notation**:

- **Session id = `AID.NNN`** (accepts `aid.001` | `001`). One repo per AID. EID is
  looked up from `aid-eid-map.tsv` (display only).
- **GitLab repos live in tier SUBGROUPS**: `aim1001/<tier>/aim1001.aid.<NNN>` —
  001-010 `01-principal-agents`, 011-025 `02-senior-agents`,
  026-075 `03-engineering-agents`, 076-100 `04-support-agents`. Branch `master`.
- **Memory repo (push target)** `/srv/aim1001/<tier>/aim1001.aid.NNN` (owner `devops:aim1001`,
  setgid 2770, shared group `aim1001`=devops+ubuntu). Script + map at **`/srv/aim1001/bin/`**.
  Sessions run as **devops** (NOT ubuntu — `/home/ubuntu` is 750, devops can't traverse it).
  Mac mirror: `~/BPR/GitRepos2/AIM1001_Team`.
- **Work home (where the agent RUNS)** `/home/devops/aid.NNN` — the agent's `CLAUDE.md` +
  the product repos it works on. SEPARATE from the memory repo. `start` cd's here and
  symlinks `08-memory` → the memory repo. Mac: runs inside the repo (no separate home).
- **Resume**: `start AID.NNN` resumes the agent's prior Claude conversation via the meta's
  `claude_uuid`. Claude history is keyed to the work-home path, so history project dirs were
  remapped `-home-devops-E#### → -home-devops-aid-NNN`. Falls back to fresh+summary if gone.
- **Memory** saved to `08-memory/long-term/aid.<NNN>.<timestamp>` (via symlink, in the repo);
  commit + push to origin master run in the **background, no terminal prompt**.
- **Git auth = `info_bnprs`** (credential in devops `~/.git-credentials`). ⚠️ `info_bnprs`
  must be **Maintainer on group `aim1001`** — `master` is a protected branch, Developer
  push is rejected by the pre-receive hook.
- **Legacy migration done**: 30 old `E####`/`C####` devops sessions mapped to AIDs; 25
  AI-summarized + 4 stubs written to each repo's `08-memory/long-term/aid.NNN.legacy-summary.md`.
  `C1039` dropped (its AID.035 reassigned to E1039; E1013→039, E1022→040).

**Why:** consistent AID-based identity across the 100 employee agents; one secure shared
location; service-account (info_bnprs) git ops.

**How to apply:** edit the canonical copy in the repo nucleus, then deploy to EC2 via the
SSH-stdin method (scp disabled — see [[project-bnprs-claude-scp]]). Reach the EC2 host via
[[bnprs-claude-vpn]] (SG is VPN-IP-only).
