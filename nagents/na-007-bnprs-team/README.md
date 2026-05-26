# na-007-bnprs-team — BNPRS Employee Agent IDs

All BNPRS employees have a personal Agent ID (AID).
Each AID maps to an individual agent folder inside this group.

## Employee Agent IDs (AIDs)

| AID   | Employee Name | Role / Department | Status  |
|-------|--------------|-------------------|---------|
| <!-- AID-001 | Full Name | Role | active --> |

## AID Format

```
AID-<3-digit-number>    e.g. AID-001, AID-042
```

- Codes run AID-001 to AID-255
- One AID per employee — permanent, never reassigned
- Each AID has a corresponding agent folder in this group (git-ignored)
- Retired employees keep their AID with status: inactive

## Notes

- Agent folders (AID-NNN/) are git-ignored — only this file is tracked
- Individual agent contents include daily deliverables, workflows, and memory
- Deliverable naming: `<employeeid>-<YYYY-MM-DD>-<sprinttaskid>.md`
