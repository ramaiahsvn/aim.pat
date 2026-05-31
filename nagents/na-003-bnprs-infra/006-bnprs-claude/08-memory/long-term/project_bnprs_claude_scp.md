---
name: project-bnprs-claude-scp
description: bnprs-claude EC2 has scp/sftp intentionally disabled; transfer files via ssh stdin/stdout
metadata: 
  node_type: memory
  type: project
  originSessionId: 3e957bc2-5476-47e3-80bf-6ee8098cda91
---

On the **bnprs-claude** EC2 instance (na-003/006, `aim1001-bnprs-claude`, `3.151.67.208`,
`ssh bnprs-claude`), the SFTP subsystem is **intentionally disabled** — so `scp` fails with
`Connection closed` (modern OpenSSH ≥9 uses SFTP under the hood). This is a deliberate
hardening choice the user confirmed; do **not** suggest or attempt to re-enable it.

**Why:** security hardening — the user wants scp/sftp off on this host.

**How to apply:** transfer files over the plain SSH channel instead.
- Push:  `ssh bnprs-claude 'cat > /path/file' < localfile`  (backup + atomic mv for safety)
- Pull:  `ssh bnprs-claude 'cat /path/file' > localfile`
- Verify byte-perfect with a sha256 compare (`shasum -a 256` local vs `sha256sum` remote).

Deployment target for the session manager: `/home/ubuntu/bnprs-sessions.sh`
(see nucleus deploy step). Regular `ssh host '<command>'` works normally.
Related: [[bnprs-claude-vpn]]
