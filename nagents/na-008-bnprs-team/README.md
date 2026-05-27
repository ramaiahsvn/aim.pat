# na-008-bnprs-team — BNPRS Employee Agent IDs

All BNPRS employees have a personal Agent ID (AID).
Each AID maps to an individual agent folder inside this group.

## Employee Agent IDs (AIDs)

| AID     | EID    | Employee Name | Role / Department | Status  |
|---------|--------|--------------|-------------------|---------|
| <!-- AID-001 | E1001 | Full Name | Role | active --> |

## AID Format

```
AID-<3-digit-number>    e.g. AID-001, AID-042
EID: actual HR employee ID  e.g. E1001, E1005
```

- AID is the agent sequence number (auto-assigned 001–999)
- EID is the employee's actual HR ID — AID maps to EID
- One AID per employee — permanent, never reassigned
- Each AID has a corresponding agent folder in this group (git-ignored)
- Retired employees keep their AID with status: inactive

## Creating a New Employee Agent

Run the script from this folder:

```bash
cd nagents/na-008-bnprs-team
./create-agent-real.sh
```

The script will:
1. Prompt for employee name, EID, and role
2. Auto-assign the next AID (AID-001, AID-002, ...)
3. Scaffold `aim1001.aid-XXX/` from `nagent-template-2`
4. `git init` the folder and make an initial commit
5. Create the GitLab project under `aim1001` group on `gitlab.bnprs.ai`
6. Push to GitLab with default branch `master`
7. Print the row to add to this README

After running, add the employee row to the table above.

## GitLab

- **Group**: `aim1001` — AIM Team (`https://gitlab.bnprs.ai/aim1001`)
- **Project naming**: `aim1001.aid-XXX`
- **Default branch**: `master`
- **Credentials**: stored in `create-agent-real.sh` (this folder, git-ignored)

## Agent Structure (nagent-template-2)

```
aim1001.aid-XXX/
  agent.yaml              Agent manifest
  CLAUDE.md               Agent identity and directives
  01-dand/
    context.yaml          Employee info, project context, git repos, inputs
  04-axon/                Task workflow definitions
  07-term/
    deliverables/         <EID>-<YYYY-MM-DD>-<sprinttaskid>.md
  08-memo/
    session/              Current task scratch
    long-term/            Persistent notes and preferences
```

## Notes

- Agent folders (`aim1001.aid-*/`) are git-ignored in this repo — only this README is tracked
- Each employee's agent repo lives independently on GitLab (`gitlab.bnprs.ai/aim1001/`)
- Deliverable naming: `<EID>-<YYYY-MM-DD>-<sprinttaskid>.md`
- **Exception**: agents in this group do NOT follow the standard nagent-template structure
