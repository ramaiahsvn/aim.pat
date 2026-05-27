# nagents — Agent Groups

All deployed nagent instances, organised by domain group.
Each group folder contains one or more individual agents,
each structured following the `nagent-template/` blueprint.

## Groups

| ID  | Group                    | Domain                                      |
|-----|--------------------------|---------------------------------------------|
| 001 | na-001-personal          | Personal productivity, life management      |
| 002 | na-002-bnprs-core        | Core business operations, admin, strategy   |
| 003 | na-003-bnprs-infra       | Infrastructure, DevOps, platform            |
| 004 | na-004-bnprs-biometrics  | Biometrics products and research            |
| 005 | na-005-bnprs-fintech     | Fintech products and financial workflows    |
| 006 | na-006-bnprs-deployments | Release management, CI/CD, environments     |
| 008 | na-008-bnprs-team        | BNPRS employee agents — one agent per employee (AIDs)               |

## Structure

```
nagents/
  na-00N-<group>/
    <agent-name>/          ← one folder per nagent instance
      01-dendrite/
      02-cell-body/
      03-nucleus/
      04-axon/
      05-myelin-sheath/
      06-node-of-ranvier/
      07-axon-terminals/
      08-memory/
      agent.yaml
```

## Creating a New Agent

1. Copy `nagent-template/` into the appropriate group folder
2. Rename the folder to describe the agent (e.g. `daily-briefing`)
3. Edit `03-nucleus/CLAUDE.md` — set identity, role, guardrails
4. Edit `agent.yaml` — fill in name, version, created_by
5. Add agent-specific secrets to `01-dendrite/secrets/secrets.yaml`
6. Wire up shared secrets from `../../secrets/secrets.yaml`
