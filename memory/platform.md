# Platform Memory — aim.pat

> Architecture decisions and conventions that apply across all agents and groups.
> Update this file when a platform-level decision is made or changed.

## Repo

- Root: `~/BPR/GitRepos1/aim.pat`
- Remote: `github.com/ramaiahsvn/aim.pat`
- Branch: `main`
- Machine: `bnprss-mbp-lan` (Darwin 25.5.0, arm64)

## Agent Code System

- Codes run `001` → `255` per group (255 max); `000` is reserved — never assign
- Inspired by ISO 8583 DE numbering — docs may reference them as DE001, DE002, etc.
- Codes are **permanent** — never reused even after retirement
- Next code = lowest unused decimal value in the group registry
- Folder naming: `<NNN>-<slug>/` e.g. `001-pat-todo/` (3-digit zero-padded decimal)
- All assignments recorded in `nagents/<group>/registry.yaml`

## Session Startup Protocol

- **Step 0** — Load `memory/platform.md`, `memory/user.md`, `memory/agents.md`
- **Step 1** — Group selection — list all groups with ID, name, agent count
- **Step 2** — Agent selection — list agents in chosen group; offer "+ Create new agent"
- **Step 3** — Sub-session init — read chosen agent's `03-nucleus/CLAUDE.md`, confirm active agent

## Folder Conventions

```
nagents/<group>/registry.yaml          ← permanent code assignments (001–255)
nagents/<group>/<NNN>-<slug>/          ← agent root (01–08 + agent.yaml)
secrets/credentials-map.yaml          ← credential location reference (no real secrets)
secrets/shell-exports.sh              ← git-ignored shell secrets (sourced in .zshrc)
memory/                               ← this folder — platform-wide memory
memory/private/                       ← git-ignored sensitive memory
```

## Template Placeholders (nagent-template)

`create-agent.sh` substitutes these in `agent.yaml` and `03-nucleus/CLAUDE.md`:

| Placeholder        | Replaced with              |
|--------------------|----------------------------|
| `<Agent Name>`     | Agent name (e.g. pat-todo) |
| `<code>`           | Decimal code (e.g. 001)    |
| `<group>`          | Group folder name          |
| `<Primary Role>`   | Role description           |
| `<Your Name>`      | `whoami` output            |
| `<date>`           | `YYYY-MM-DD`               |
| `<What this agent does>` | Role description     |

## Templates

### nagent-template (standard)
- Full 8-folder neuron anatomy (01-dendrite → 08-memory)
- Used for all aim.pat agents across groups na-001 to na-006
- `create-agent.sh` scaffolds from this template

### nagent-template-2 (external employee agents)
- Simplified 4-component structure: `01-dand/`, `04-axon/`, `07-term/`, `08-memo/`
- **NOT used inside the aim.pat repo** — for standalone per-employee agent repos on GitLab
- `01-dand/context.yaml` — project name, tasks, repo URLs, general inputs
- `07-term/` deliverables naming: `<employeeid>-<YYYY-MM-DD>-<sprinttaskid>.md`
- `create-agent-real.sh` in na-008-bnprs-team scaffolds from this template

## Exceptional Groups

### na-008-bnprs-team
- Contains employee AID (Agent ID) ↔ EID (Employee ID) registry only
- All contents git-ignored **except**: `README.md`, `create-agent-real.sh`, `.gitignore`
- Agent folders (`aim1001.aid-XXX/`) are created locally and pushed to gitlab.bnprs.ai/aim1001
- Does NOT follow nagent-template structure — each employee agent is a standalone Git repo

## Scripting Notes

- `create-agent.sh` uses `mapfile` (bash 4+) — fails on macOS default bash 3.2
- Workaround: create agents manually or install bash via Homebrew
- Script supports non-interactive mode: `--group`, `--name`, `--role` flags

## Git Hygiene

- `secrets/secrets.yaml` — git-ignored
- `secrets/shell-exports.sh` — git-ignored (holds GITLAB_PAT and other shell secrets)
- `memory/private/` — git-ignored
- `nagents/**/01-dendrite/secrets/secrets.yaml` — git-ignored
