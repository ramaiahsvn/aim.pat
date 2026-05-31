---
name: project-bnprs-claude-vpn
description: "OpenVPN config for aim1001-bnprs-claude EC2 — stored in agent secrets folder, git-ignored"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d20ff47-3cf9-442e-ae4c-cc024cc3e7ba
---

OpenVPN config for `aim1001-bnprs-claude` (3.151.67.208, us-east-2):

- **File**: `nagents/na-003-bnprs-infra/006-bnprs-claude/01-dendrite/secrets/bnprs-claude.ovpn`
- **Git-ignored**: yes (secrets/.gitignore ignores everything)
- **Connect**: `open "nagents/na-003-bnprs-infra/006-bnprs-claude/01-dendrite/secrets/bnprs-claude.ovpn"`
- **Required**: VPN must be connected before SSH if not on office IP

**Why:** EC2 SG `sg-0cf061a2c32667858` only allows port 22 from office IPs. VPN tunnels through to make SSH work from any location.

**How to apply:** When SSH to 3.151.67.208 times out, prompt user to connect VPN first using the above path. [[project-na003-agents]]
