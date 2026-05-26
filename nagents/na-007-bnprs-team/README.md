# na-007-bnprs-team — BNPRS Employee Agent IDs

All BNPRS employees have a personal Agent ID (AID).
Each AID maps to an individual agent folder inside this group.

## Employee Agent IDs (AIDs)

| AID    | EID    | Employee Name | Role / Department | Status  |
|--------|--------|--------------|-------------------|---------|
| <!-- AID-01 | E1001 | Full Name | Role | active --> |

## AID Format

```
AID-<2-digit-number>    e.g. AID-01, AID-42
EID: actual HR employee ID  e.g. E1001, E1005
```

- AID is the agent sequence number (assigned in any order)
- EID is the employee's actual HR ID — AID maps to EID
- One AID per employee — permanent, never reassigned
- Each AID has a corresponding agent folder in this group (git-ignored)
- Retired employees keep their AID with status: inactive

## Notes

- Agent folders (AID-NNN/) are git-ignored — only this file is tracked
- Individual agent contents include daily deliverables, workflows, and memory
- Deliverable naming: `<employeeid>-<YYYY-MM-DD>-<sprinttaskid>.md`
- **Exception**: agents in this group do NOT follow the standard nagent-template structure
