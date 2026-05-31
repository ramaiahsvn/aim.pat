# BNA Team Status + Efficiency Workflow

> Long-term memory for **BNA Orchestrator** (na-010/001). Operational with the
> **Team Liaison** (na-010/004), which owns na-008 (100 agents, 4 tiers). All team
> agents run on the bnprs-claude EC2 via `bnprs-sessions.sh` (na-003/006).

## Per-session work summary + efficiency rating (built into the session manager)

On session end, `cmd_start` resumes the just-ended conversation non-interactively
(`claude -p --resume <uuid>`) and asks for:
1. a 3–8 bullet **work summary** (only what was accomplished this session)
2. a self-rated **`EFFICIENCY: N/10 — reason`** line

Rubric (in the prompt, calibrated, "do not inflate"): 1–3 stuck/trivial · 4–6
progress with rework · 7–8 solved cleanly · 9–10 hard problem solved fast.

- Functions in `bnprs-sessions.sh`: `generate_session_summary`, `parse_efficiency`,
  `record_efficiency`.
- Summary → becomes the memory-file body (replaces the old empty 172-byte marker).
- Rating → appended to a **per-agent daily ledger**
  `08-memory/long-term/efficiency.<aid>.csv`
  cols: `date,time,aid,eid,rating,resume_count,rationale`.
- Toggle `BNPRS_SESSION_SUMMARY=0`; timeout `BNPRS_SUMMARY_TIMEOUT` (default 150s).
- aim.pat commits: `4d013af` (summary), `84f951e` (rating), `0cd4d58` (report cmd).

## Report command

```
~/bnprs-sessions.sh efficiency [AID.NNN | YYYY-MM-DD | all]
```
(alias `eff`; default = today across all agents + team average). **CSV-safe:**
rationale is parsed as everything after the 6th comma (`$7..$NF`) — never read it
with a plain `cut -d, -f7` (commas in the text would truncate it; that was the
aid.030 display bug).

## Gotcha — detecting "who worked today"

Do **not** scope the active set by git-commits-today. The pre-patch manager only
auto-committed an empty marker, and a session that exits without that firing leaves
**no commit at all** → commit-based detection UNDERCOUNTS. (On 2026-05-31 it missed
aid.011 + aid.040; true active = 24, not 22.) The reliable signal is a **today-dated
transcript** in `~/.claude/projects/-home-devops-aid-NNN/*.jsonl`. To find gaps: list
agents with a today transcript but no today ledger row.

## Backfilling a day from transcripts

When summaries/ratings are missing for a past day: for each active agent,
`claude -p --resume <today-uuid>` with the summary+efficiency prompt → write
`aid.NNN.<ts>.backfill` + the ledger row → commit+push the memory repo
(`git push origin master` as info_bnprs via the isolated credential).

- **Run sequentially with ≥30s spacing + retry/backoff.** Firing ~22 `claude -p`
  calls back-to-back trips Anthropic's rate limiter ("Server is temporarily limiting
  requests"), which returns an error, not a rating (NA). Re-run NA agents spaced out.
- Big transcripts (50–150 MB) are slow — use per-call `timeout 600`, run via `nohup`
  in the background, poll results; don't block.

## First run (2026-05-31, backfilled)

24 active agents, **team average 6.46/10**. Distribution 8×7 · 7×8 · 6×5 · 5×1 · 4×2 · 1×1.
Top: aid.018/020/028/029/032/037/040 (8). Bottom: aid.003 (1, no work), aid.002 &
aid.033 (4, blocked/undelivered). All ledgers committed + pushed to each agent's
GitLab repo.

## Caveats

- Ratings are a **self-assessment** by the same model from the transcript — a relative
  trend signal, not an independent audit. (Option: switch to a separate judge call.)
- aid.032–035's transcripts include the platform's own remap/identity work, so their
  scores partly reflect that, not pure product delivery.

## How to change it

Edit the canonical `bnprs-sessions.sh` in `na-003-bnprs-infra/006-bnprs-claude/03-nucleus/`,
deploy to EC2 `/home/devops` + `/srv/aim1001/bin` via ssh-stdin (scp disabled), commit
to aim.pat main. This Mac (pat-m4p) has **no `timeout`** — use ssh's `-o ConnectTimeout`;
capture remote output via `base64 -w0` to avoid channel garble.
