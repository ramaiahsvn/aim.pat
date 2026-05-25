# Platform Memory — aim.pat

> Architecture decisions and conventions that apply across all agents and groups.
> Update this file when a platform-level decision is made or changed.

## Repo

- Root: `~/BPR/GitRepos1/aim.pat`
- Remote: `github.com/ramaiahsvn/aim.pat`
- Branch: `main`
- Machine: `bnprss-mbp-lan` (Darwin 25.5.0, arm64)

## Agent Code System

- Codes run `01` → `FF` per group (255 max); `00` is reserved — never assign
- Inspired by ISO 8583 DE numbering — docs may reference them as DE01, DE02, etc.
- Codes are **permanent** — never reused even after retirement
- Next code = lowest unused hex in the group registry
- Folder naming: `<HH>-<slug>/` e.g. `01-pat-todo/`
- All assignments recorded in `nagents/<group>/registry.yaml`

## Session Startup Protocol (3-step)

1. **Group selection** — list all groups with ID, name, agent count
2. **Agent selection** — list agents in chosen group; offer "+ Create new agent"
3. **Sub-session init** — read chosen agent's `03-nucleus/CLAUDE.md`, confirm active agent

## Folder Conventions

```
nagents/<group>/registry.yaml          ← permanent DE code assignments
nagents/<group>/<DE##>-<slug>/         ← agent root (01–08 + agent.yaml)
secrets/credentials-map.yaml          ← credential location reference (no real secrets)
secrets/shell-exports.sh              ← git-ignored shell secrets (sourced in .zshrc)
memory/                               ← this folder — platform-wide memory
memory/private/                       ← git-ignored sensitive memory
```

## Scripting Notes

- `create-agent.sh` uses `mapfile` (bash 4+) — fails on macOS default bash 3.2
- Workaround: create agents manually or install bash via Homebrew
- Script supports non-interactive mode: `--group`, `--name`, `--role` flags

## Git Hygiene

- `secrets/secrets.yaml` — git-ignored
- `secrets/shell-exports.sh` — git-ignored (holds GITLAB_PAT and other shell secrets)
- `memory/private/` — git-ignored
- `nagents/**/01-dendrite/secrets/secrets.yaml` — git-ignored
