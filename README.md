# aim.pat — AI Agent Management Platform

A structured platform for building and managing AI agents modelled on biological
neuron anatomy. Each agent is a **nagent** — a self-contained unit with 8
numbered folders that map directly to neuron components and agent functions.

---

## Architecture at a glance

```
aim.pat/
  nagent-template/          ← canonical blueprint for every agent
  nagents/
    na-001-personal/        ← agent group
      registry.yaml         ← permanent DE code ledger
      DE01-daily-briefing/  ← individual agent
        01-dendrite/        inputs: connectors, APIs, sensors
        02-cell-body/       reasoning: LLM config, planning, strategies
        03-nucleus/         identity: system-prompt, persona, guardrails
        04-axon/            workflows: multi-step execution pipelines
        05-myelin-sheath/   skills: pre-built expertise packages
        06-node-of-ranvier/ checkpoints: quality gates, human-in-the-loop
        07-axon-terminals/  outputs: files, messages, notifications
        08-memory/          memory: session, long-term, user prefs
        agent.yaml          agent manifest
    na-002-bnprs-core/
    na-003-bnprs-infra/
    na-004-bnprs-biometrics/
    na-005-bnprs-fintech/
    na-006-bnprs-deployments/
    na-007-bnprs-cxo/
    na-008-bnprs-team/
  secrets/                  ← shared secrets (git-ignored)
  create-agent.sh           ← interactive scaffolding script
  nagent.svg                ← neuron anatomy diagram
```

---

## Neuron → Agent mapping

```
#   Neuron Component        Agent Component         Folder
──  ──────────────────────  ──────────────────────  ─────────────────────
01  Dendrite                Resources / Inputs      01-dendrite/
02  Cell Body               Agent Core (LLM)        02-cell-body/
03  Nucleus                 Identity / DNA          03-nucleus/
04  Axon                    Workflows               04-axon/
05  Myelin Sheath           Skills                  05-myelin-sheath/
06  Node of Ranvier         Checkpoints             06-node-of-ranvier/
07  Axon Terminals          Outputs / Actions       07-axon-terminals/
08  Synaptic Plasticity     Memory                  08-memory/
```

Signal flow: `01 RECEIVE → 02 INTEGRATE ↔ 03 IDENTITY → 04 EXECUTE → 05 ACCELERATE → 06 VERIFY → 07 OUTPUT ↻ 08 REMEMBER`

---

## Agent groups

| Code | Group                    | Domain                                                                    |
|------|--------------------------|---------------------------------------------------------------------------|
| 001  | na-001-personal          | Personal productivity, life management, day-to-day automation             |
| 002  | na-002-bnprs-core        | Core business ops, administration, strategy                               |
| 003  | na-003-bnprs-infra       | Infrastructure, DevOps, platform operations                               |
| 004  | na-004-bnprs-biometrics  | Biometrics product development and research                               |
| 005  | na-005-bnprs-fintech     | Fintech products and financial workflows                                   |
| 006  | na-006-bnprs-deployments | Release management, CI/CD pipelines, environments                         |
| 007  | na-007-bnprs-cxo         | CXO agents — CEO, CTO, CFO, COO and related                               |
| 008  | na-008-bnprs-team        | BNPRS employee agents — one agent per employee (AIDs)                     |

---

## Agent code system (ISO 8583 DE-style)

Agent codes use a **1-byte Data Element (DE) scheme** inspired by ISO 8583:

```
DE01  first agent in the group       (hex 0x01)
DE02  second agent                   (hex 0x02)
...
DEFF  255th agent — group maximum    (hex 0xFF)
```

### Rules

| Rule | Detail |
|------|--------|
| Range | DE01 to DEFF — DE00 is reserved |
| Capacity | 255 agents per group |
| Permanence | A code is **never reassigned** once used, even after agent deletion |
| Retirement | Retired agents keep their code with `status: retired` |
| Allocation | Always use the lowest available hex code |
| Ledger | All assignments recorded in `nagents/<group>/registry.yaml` |

### Why DE codes?

ISO 8583 is a financial messaging standard where each Data Element carries a
fixed, permanent meaning. The same principle applies here: every DE code has a
single, permanent identity within its group. This makes agent references stable
across time — a code in a log, a message, or a config always points to the same
agent regardless of renames or restructuring.

---

## Creating a new agent

Run from the repo root:

```bash
./create-agent.sh
```

Interactive flow:

```
1. Select group      — lists all groups with agent counts
2. Code assigned     — next available DE code auto-selected
3. Name + role       — prompted if not passed as flags
4. Confirm           — shows summary before creating
5. Scaffold          — copies nagent-template/ into group folder
6. Register          — writes permanent entry to registry.yaml
```

Non-interactive (CI / scripted):

```bash
./create-agent.sh --group na-001 --name "Daily Briefing" --role "Briefing Specialist"
```

---

## Registry format

Each group maintains a `registry.yaml` as its permanent ledger:

```yaml
group:
  id: "na-001"
  name: "personal"
  max_agents: 255

registry:
  - code: "DE01"
    name: "daily-briefing"
    label: "Daily Briefing"
    role: "Briefing Specialist"
    path: "DE01-daily-briefing"
    status: "active"          # active | retired
    created_at: "2026-05-25"
    created_by: "bnprs"
```

Retired agents:

```yaml
  - code: "DE03"
    name: "old-bot"
    status: "retired"         # code is locked — never reassigned
    retired_at: "2026-08-01"
```

---

## Secrets

```
secrets/                              shared across all agents
  secrets.example.yaml  →  secrets.yaml   (git-ignored)

nagents/<group>/<agent>/01-dendrite/secrets/
  secrets.example.yaml  →  secrets.yaml   (git-ignored)
```

**Shared** (`secrets/secrets.yaml`): LLM API keys, Slack bot token, S3, databases.
**Per-agent** (`01-dendrite/secrets/secrets.yaml`): connector tokens, API keys, per-agent overrides.

Never commit real credentials. All `secrets/` folders are git-ignored except the `.example.yaml` templates.

---

## Quick reference

```bash
./create-agent.sh                      # create a new agent (interactive)
./create-agent.sh --help               # show options

cat nagents/na-008-bnprs-team/README.md          # view team employee AIDs
ls  nagents/na-001-personal/                 # list personal agents
```
