# aim.pat — AI Agent Management Platform

> This file is read by Claude at the start of every session in this folder.

## What this repo is

**aim.pat** is the central platform for building, managing, and running AI agents
structured as biological neurons (the **nagent** architecture). Each agent mirrors
the anatomy of a multipolar neuron across 8 numbered folders (01–08), following
signal flow from inputs to outputs to memory.

## Session startup — always do this first

At the start of every session, before anything else:

**Step 0 — Load global memory**
Read all files in `memory/` (skip `memory/private/` unless relevant):
- `memory/platform.md` — architecture decisions, conventions, repo layout
- `memory/user.md` — user profile and preferences
- `memory/agents.md` — active agents and cross-agent context

**Step 1 — Group selection**
1. Read `nagents/` and list all group folders
2. Display the group menu — show ID, name, agent count, and description
3. Ask the user to select a group (or "all" to work across groups)

**Step 2 — Agent selection** (once a group is chosen)
4. Read the group's `registry.yaml` and display all agents in a numbered list:
   - Code, name, role, status (active / retired)
   - Total used / 255 slots
   - Include a "+ Create new agent" option at the bottom
5. Ask the user to select an agent by number (or choose to create a new one)

**Step 3 — Sub-session initialization** (once an agent is chosen)
6. Read that agent's `03-nucleus/CLAUDE.md` and load it as the active context
7. Confirm which agent is now active: display its code, name, role, and status
8. Ask what the user wants to do with this agent

**If the user chooses "Create new agent"** at step 5:
- Run `./create-agent.sh`

**If the user says "all"** at step 1:
- Skip steps 2–3 and ask what platform-level management task to perform

## Agent groups

| ID  | Folder                   | Domain                                                              |
|-----|--------------------------|---------------------------------------------------------------------|
| 001 | na-001-personal          | Personal productivity, life management                              |
| 002 | na-002-bnprs-core        | Core business operations, admin, strategy                           |
| 003 | na-003-bnprs-infra       | Infrastructure, DevOps, platform                                    |
| 004 | na-004-bnprs-biometrics  | Biometrics product development and research                         |
| 005 | na-005-bnprs-fintech     | Fintech products and financial workflows                            |
| 006 | na-006-bnprs-deployments | Release management, CI/CD, environments                             |
| 007 | na-007-bnprs-zoo         | Enterprise portal: people, payroll, contracts, sprints, projects, expenses, inventory |

## Agent code system

Each group supports up to **255 agents**, identified by a 1-byte hex code:

```
01 → first agent in group
02 → second agent
...
FF → 255th agent (maximum)
```

Inspired by ISO 8583 Data Element (DE) numbering — you may see these referred
to as DE01, DE02, etc. in documentation and external references.

**Rules — enforce strictly:**
- Codes run 01 to FF (00 is reserved/invalid)
- Once a code is assigned it is **permanent** — never reassigned, even if the agent is deleted or retired
- Retired agents keep their code with `status: retired` in `registry.yaml`
- The next available code is always the lowest unused hex value
- All assignments are recorded in `nagents/<group>/registry.yaml`

## Creating a new agent

Run the interactive script from the repo root:

```bash
./create-agent.sh
```

The script will:
1. Show all groups → user selects one
2. Auto-assign the next code from the group registry
3. Prompt for agent name and role
4. Scaffold the full 01–08 folder structure from `nagent-template/`
5. Register the new agent in `registry.yaml` (permanent entry)

## Secrets

```
secrets/                          ← shared across all agents
  secrets.example.yaml            ← copy → secrets.yaml (git-ignored)

nagents/<group>/<agent>/
  01-dendrite/secrets/
    secrets.example.yaml          ← copy → secrets.yaml (git-ignored)
```

Shared secrets: LLM API keys, Slack, storage, databases.
Per-agent secrets: connector credentials, API tokens for that agent only.

## Neuron anatomy → agent component map

```
01-dendrite         Resources / Inputs      MCP connectors, APIs, sensors
02-cell-body        Agent Core (LLM)        Reasoning, planning, models, strategies
03-nucleus          Identity / DNA          system-prompt, persona, guardrails (read-only)
04-axon             Workflows               Multi-step execution pipelines
05-myelin-sheath    Skills                  Pre-built expertise packages (SKILL.md)
06-node-of-ranvier  Checkpoints             Quality gates, human-in-the-loop
07-axon-terminals   Outputs                 File delivery, notifications, actions
08-memory           Memory                  Short-term (session), long-term, user prefs
```

Signal flow: `01 → 02 ↔ 03 → 04 → 05 → 06 → 07 ↻ 08`

## Key files

```
aim.pat/
  CLAUDE.md                 ← this file (Claude reads on session start)
  README.md                 ← full platform documentation
  create-agent.sh           ← interactive agent creation script
  nagent-template/          ← canonical template (01–08 folders)
  nagents/
    na-00N-<group>/
      registry.yaml         ← permanent code assignments (01–FF)
      <HH>-<name>/          ← individual agent (01–08 folders + agent.yaml)
  secrets/
    secrets.example.yaml    ← shared secrets template
  memory/
    platform.md             ← platform decisions and conventions
    user.md                 ← user profile and preferences
    agents.md               ← active agents and cross-agent context
    private/                ← git-ignored sensitive memory
```
