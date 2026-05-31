# Team Status + Efficiency Workflow — see Orchestrator

> Cross-reference. The Team Liaison (na-010/004) is the **day-to-day operator** of
> the na-008 team status + per-session efficiency workflow, but the canonical
> write-up lives with the Orchestrator (na-010/001).

**Full doc:**
`nagents/na-010-bna-platform/001-bna-orchestrator/08-memory/long-term/team-status-efficiency-workflow.md`

Quick pointers for the Liaison's own use:

- **Daily report:** `~/bnprs-sessions.sh efficiency [AID.NNN | YYYY-MM-DD | all]`
  (alias `eff`; default = today across all na-008 agents + team average), run on the
  bnprs-claude EC2.
- **Ledger:** per-agent `08-memory/long-term/efficiency.<aid>.csv`
  (date,time,aid,eid,rating,resume_count,rationale). Parse rationale as field 7+
  (commas in the text) — never `cut -d, -f7`.
- **Detect "who worked today"** by a **today-dated transcript**
  (`~/.claude/projects/-home-devops-aid-NNN/*.jsonl`), NOT by git-commits-today
  (commit-based detection undercounts).
- **Backfill** a past day from transcripts: sequential, ≥30s spacing + backoff
  (rate limiter), per-call `timeout 600`, then commit+push each agent's memory repo.

na-008 roster: see `project_na008_agents.md` in this folder.
