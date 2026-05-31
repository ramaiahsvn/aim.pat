#!/bin/bash
# ============================================================
#  BNPRS Session Manager for Claude Code CLI
#  Session ID format (NEW):  AID.NNN     e.g.  AID.001  (also: aid.001 | 001)
# ============================================================
#
#  Usage:
#    ./bnprs-sessions.sh init
#    ./bnprs-sessions.sh start AID.001          # Start or resume (employee agent aid.001)
#    ./bnprs-sessions.sh sync  AID.001          # Sync repo only
#    ./bnprs-sessions.sh list                   # List all local sessions
#    ./bnprs-sessions.sh status AID.001         # Session details
#    ./bnprs-sessions.sh delete AID.001         # Delete local session meta
#    ./bnprs-sessions.sh save-memory AID.001 ["notes"]   # Save memory (non-interactive, bg push)
#
#  Notation (NEW — 2026-05-30):
#    Sessions are keyed by AGENT ID (AID), not employee id. One repo per AID:
#      aim1001.aid.<NNN>  under GitLab subgroup  aim1001/<tier>/
#    Tier by AID range: 001-010 principal | 011-025 senior |
#                       026-075 engineering | 076-100 support
#    Employee/contractor id (EID) is looked up from aid-eid-map.tsv (display only).
#
#  Memory:
#    Saved per session into  <repo>/08-memory/long-term/aid.<NNN>.YYYY.MM.DD.HH.MM.SS
#    Commit + push to origin happen in the BACKGROUND, with NO terminal prompt.
#
#  Env vars (override defaults):
#    GITLAB_HOST       default: gitlab.bnprs.ai
#    GITLAB_GROUP      default: aim1001
#    BNPRS_GIT_USER    git remote user for new clones (default: info_bnprs on Linux)
#    BNPRS_REPOS_DIR   local clone base dir
#                        macOS default: ~/BPR/GitRepos2/AIM1001_Team
#                        Linux default: /srv/aim1001
#    BNPRS_AID_MAP     path to aid-eid-map.tsv (default: alongside this script)
#    CLAUDE_CMD        claude binary  default: auto-resolved (PATH, then ~/.local/bin, ...)
#    BNPRS_GIT_PASSWORD one-time: prime info_bnprs into the credential store (used by init)
#
#  Authentication: git uses a persistent 'store' credential helper (info_bnprs on EC2).
#    'init' ensures the helper exists and (if BNPRS_GIT_PASSWORD is set) primes the
#    stored credential once; sync/start re-ensure the helper, so a wiped devops
#    gitconfig self-heals as long as ~/.git-credentials survives.
#
#  On agent load: run sync-all to pull all cloned repos.
# ============================================================

set -uo pipefail

# ── Config ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="$HOME/.claude/bnprs-sessions"
MEMORY_DIR="$HOME/.claude/bnprs-memory"
GITLAB_HOST="${GITLAB_HOST:-gitlab.bnprs.ai}"
GITLAB_GROUP="${GITLAB_GROUP:-aim1001}"
AID_MAP="${BNPRS_AID_MAP:-$SCRIPT_DIR/aid-eid-map.tsv}"

# Ensure ~/.local/bin is on PATH — non-login / non-interactive invocations
# (e.g. `sudo -u devops ...`) do NOT source ~/.profile, where it is normally added,
# so `claude` would otherwise be "command not found".
[[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"

# Resolve the claude binary robustly (bare `claude` fails with "command not found"
# under shells that never sourced ~/.profile). Honor an explicit CLAUDE_CMD override.
if [[ -z "${CLAUDE_CMD:-}" ]]; then
    if command -v claude >/dev/null 2>&1; then
        CLAUDE_CMD="$(command -v claude)"
    else
        for _c in "$HOME/.local/bin/claude" /usr/local/bin/claude /usr/bin/claude /snap/bin/claude; do
            [[ -x "$_c" ]] && { CLAUDE_CMD="$_c"; break; }
        done
        CLAUDE_CMD="${CLAUDE_CMD:-claude}"
    fi
fi

# REPOS_DIR: OS-aware default
if [[ -n "${BNPRS_REPOS_DIR:-}" ]]; then
    REPOS_DIR="$BNPRS_REPOS_DIR"
elif [[ "$(uname)" == "Darwin" ]]; then
    REPOS_DIR="$HOME/BPR/GitRepos2/AIM1001_Team"
else
    REPOS_DIR="/srv/aim1001"
fi

# Git remote user embedded in NEW clone URLs (so the right stored credential
# is selected). Empty on macOS (use whatever credential helper is configured).
if [[ -n "${BNPRS_GIT_USER:-}" ]]; then
    GIT_REMOTE_USER="$BNPRS_GIT_USER"
elif [[ "$(uname)" == "Darwin" ]]; then
    GIT_REMOTE_USER=""
else
    GIT_REMOTE_USER="info_bnprs"
fi

# Working-dir base — where the agent actually RUNS (separate from the memory repo).
# Each agent's home holds its CLAUDE.md + the product repos it works on.
#   Linux (EC2): /home/devops/aid.NNN   ·   macOS: the memory repo itself.
if [[ -n "${BNPRS_WORK_BASE:-}" ]]; then
    WORK_BASE="$BNPRS_WORK_BASE"
elif [[ "$(uname)" == "Darwin" ]]; then
    WORK_BASE=""        # on the Mac, run inside the repo (no separate work home)
else
    WORK_BASE="/home/devops"
fi

PUSH_LOG="${REPOS_DIR}/.push.log"

# macOS/Linux-compatible sed -i
if [[ "$(uname)" == "Darwin" ]]; then
    SED_I() { sed -i '' "$@"; }
else
    SED_I() { sed -i "$@"; }
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────
log()  { echo -e "${GREEN}[bnprs]${NC} $*"; }
warn() { echo -e "${YELLOW}[bnprs]${NC} $*"; }
err()  { echo -e "${RED}[bnprs]${NC} $*" >&2; }

ensure_dirs() { mkdir -p "$SESSIONS_DIR" "$MEMORY_DIR" "$REPOS_DIR" 2>/dev/null || true; }

# Ensure the git credential for the aim1001 group repos is present AND ISOLATED
# (Linux/EC2). Without this, the session manager's non-interactive clone/pull/push
# 401s → GitLab reports the private repo as "not found".
#
# WHY ISOLATION: the agent work homes also contain *product* repos
# (https://gitlab.bnprs.ai/bpr10xx/...) owned by other users. When a session does
# a git op on one of those (no username in the URL), git's shared `store` returns
# info_bnprs, the product repo 401s, and git's `reject` then ERASES the info_bnprs
# entry from the shared store. Next aim1001 op → no credential → 404. (Made worse
# by credential.useHttpPath=false, which makes the host match path-blind.)
#
# FIX: give the aim1001 group URL its OWN credential store file, selected by a
# path-scoped config section with the inherited helper reset — so product-repo ops
# (which don't match the aim1001 path) can never read or erase it. The generic
# store still serves everything else. Idempotent, self-healing; NEVER hardcodes a
# secret (primes from $BNPRS_GIT_PASSWORD only, env-only, never written to a repo).
#   $1 = "quiet" to suppress info/warn output (used on the hot sync/start paths).
ensure_git_auth() {
    local quiet="${1:-}"
    [[ "$(uname)" == "Darwin" ]] && return 0          # macOS: use system keychain helper
    [[ -n "$GIT_REMOTE_USER" ]] || return 0

    local aurl="https://${GITLAB_HOST}/${GITLAB_GROUP}"   # e.g. https://gitlab.bnprs.ai/aim1001
    local ded="$HOME/.git-credentials-${GITLAB_GROUP}"    # dedicated, isolated store

    # 1) generic persistent store for everything else (additive, idempotent)
    if ! git config --global --get-all credential.helper 2>/dev/null | grep -qx store; then
        git config --global --add credential.helper store
        [[ "$quiet" == quiet ]] || log "Configured persistent git credential helper: store"
    fi

    # 2) path-scoped isolation for the aim1001 group URL: reset inherited helpers
    #    (so the shared store is NOT consulted/erasable for these URLs), then point
    #    at the dedicated file and pin the username. Re-assert every run (cheap).
    if [[ "$(git config --global --get-all "credential.${aurl}.helper" 2>/dev/null | tr '\n' '|')" != "|store --file=${ded}|" ]]; then
        git config --global "credential.${aurl}.helper" ""               # reset inherited
        git config --global --add "credential.${aurl}.helper" "store --file=${ded}"
        [[ "$quiet" == quiet ]] || log "Isolated ${GITLAB_GROUP} credentials → ${ded}"
    fi
    git config --global "credential.${aurl}.username" "$GIT_REMOTE_USER"

    # 3) if the dedicated file lacks the info_bnprs entry, prime it from env (once)
    if ! grep -q "//${GIT_REMOTE_USER}:.*@${GITLAB_HOST}" "$ded" 2>/dev/null; then
        if [[ -n "${BNPRS_GIT_PASSWORD:-}" ]]; then
            ( umask 077; printf 'https://%s:%s@%s\n' \
                "$GIT_REMOTE_USER" "$BNPRS_GIT_PASSWORD" "$GITLAB_HOST" > "$ded" )
            chmod 600 "$ded"
            [[ "$quiet" == quiet ]] || log "Primed ${GIT_REMOTE_USER} credential → ${ded}"
        elif [[ "$quiet" != quiet ]]; then
            warn "No stored credential for ${GIT_REMOTE_USER}@${GITLAB_HOST} in ${ded}."
            warn "Prime it once:  set BNPRS_GIT_PASSWORD and re-run 'init', or run:"
            warn "  printf 'https://${GIT_REMOTE_USER}:<PW>@${GITLAB_HOST}\\n' > ${ded} && chmod 600 ${ded}"
        fi
    fi
}

# Keep the per-AID shell aliases (aNNN → cd ~/aid.NNN && start AID.NNN) current,
# so a freshly-created work home is usable by alias immediately and stale entries
# self-heal — same "just works" guarantee as PATH/credential. Linux/EC2 only
# (macOS runs inside the repo, no work homes). Idempotent: rewrites only the
# managed block between markers in the rc file, and ALSO removes any legacy
# hand-written e####/c#### aliases left from the pre-AID scheme. Quiet by default;
# pass "loud" to print a one-line summary.
ALIAS_BEGIN="# >>> BNPRS session aliases >>>"
ALIAS_END="# <<< BNPRS session aliases <<<"
ensure_aliases() {
    local loud="${1:-}"
    [[ "$(uname)" == "Darwin" ]] && return 0
    [[ -n "$WORK_BASE" && -d "$WORK_BASE" ]] || return 0
    local self="${BASH_SOURCE[0]}"
    case "$self" in /*) : ;; *) self="$(cd "$(dirname "$self")" && pwd)/$(basename "$self")";; esac
    local rc="$HOME/.bashrc"; [[ -f "$HOME/.zshrc" ]] && rc="$HOME/.zshrc"
    [[ -f "$rc" ]] || return 0

    # Build the fresh managed block from the work homes that actually exist.
    local block; block="$ALIAS_BEGIN"$'\n'
    block+="alias rs='${self}'"$'\n'
    block+="alias rsl='${self} list'"$'\n'
    local dir aid nnn
    for dir in "$WORK_BASE"/aid.[0-9]*; do
        [[ -d "$dir" ]] || continue
        aid="$(basename "$dir")"; nnn="${aid#aid.}"
        block+="alias a${nnn}='cd ${WORK_BASE}/${aid} && ${self} start AID.${nnn}'"$'\n'
    done
    block+="$ALIAS_END"

    # If the rc already contains an identical managed block and no legacy lines, skip.
    local cur; cur="$(awk "/$ALIAS_BEGIN/,/$ALIAS_END/" "$rc" 2>/dev/null)"
    local has_legacy; has_legacy="$(grep -cE "^alias [ec][0-9]{4}=" "$rc" 2>/dev/null)"
    if [[ "$cur" == "$block" && "${has_legacy:-0}" -eq 0 ]]; then
        [[ "$loud" == loud ]] && log "Aliases already current ($(grep -c "^alias a[0-9]\{3\}=" "$rc") agents)"
        return 0
    fi

    cp -p "$rc" "$rc.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    # Drop the old managed block, the legacy header, and legacy e####/c#### aliases.
    SED_I "/$ALIAS_BEGIN/,/$ALIAS_END/d" "$rc"
    SED_I '/^# ── BNPRS Session Aliases ──$/d' "$rc"
    SED_I "\#^alias [ec][0-9]\{4\}='cd ~/[EC][0-9]\{4\} #d" "$rc"
    # Collapse 3+ blank lines to one.
    awk 'BEGIN{b=0} /^$/{b++; if(b<=1) print; next} {b=0; print}' "$rc" > "$rc.tmp" 2>/dev/null \
        && mv "$rc.tmp" "$rc"
    { echo ""; printf '%s\n' "$block"; } >> "$rc"
    [[ "$loud" == loud ]] && log "Refreshed shell aliases in $rc ($(grep -c "^alias a[0-9]\{3\}=" "$rc") agents) — run: source $rc"
    return 0
}

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || uuidgen 2>/dev/null
}

session_meta_file() { echo "$SESSIONS_DIR/${1//\//_}.meta"; }

# Tier subgroup for an AID number (matches GitLab subgroups)
tier_for() {
    local n=$((10#$1))
    if   [[ $n -ge 1   && $n -le 10  ]]; then echo "01-principal-agents"
    elif [[ $n -ge 11  && $n -le 25  ]]; then echo "02-senior-agents"
    elif [[ $n -ge 26  && $n -le 75  ]]; then echo "03-engineering-agents"
    elif [[ $n -ge 76  && $n -le 100 ]]; then echo "04-support-agents"
    else echo ""; fi
}

# Look up EID for an AID number from the map file ('' if unknown)
lookup_eid() {
    local nnn="$1"
    [[ -f "$AID_MAP" ]] || { echo ""; return; }
    awk -v a="$nnn" '!/^#/ && $1==a {print $2; found=1} END{if(!found) print ""}' "$AID_MAP" | head -1
}

# ── Session ID Parsing ───────────────────────────────────────
# Accepts: AID.001 | aid.001 | 001   →  normalizes to aid.NNN
# Exports: SESSION_AID_NUM, SESSION_AID, SESSION_EID, SESSION_TIER,
#          SESSION_REPO_NAME, SESSION_REPO_URL, SESSION_LOCAL_PATH, SESSION_ID
parse_session_id() {
    local raw="$1" nnn=""
    raw="${raw#[Aa][Ii][Dd].}"          # strip leading AID. / aid.
    if [[ "$raw" =~ ^[0-9]{1,3}$ ]]; then
        nnn=$(printf '%03d' "$((10#$raw))")
    else
        err "Invalid session ID: '$1'"
        err "Expected:  AID.<NNN>   e.g.  AID.001   (also accepts aid.001 or 001)"
        exit 1
    fi
    local n=$((10#$nnn))
    if [[ $n -lt 1 || $n -gt 100 ]]; then
        err "AID out of range (001-100): '$1'"; exit 1
    fi

    SESSION_AID_NUM="$nnn"
    SESSION_AID="aid.$nnn"
    SESSION_ID="aid.$nnn"
    SESSION_EID="$(lookup_eid "$nnn")"
    SESSION_TIER="$(tier_for "$nnn")"
    SESSION_REPO_NAME="${GITLAB_GROUP}.aid.$nnn"          # aim1001.aid.001
    local userpart=""
    [[ -n "$GIT_REMOTE_USER" ]] && userpart="${GIT_REMOTE_USER}@"
    SESSION_REPO_URL="https://${userpart}${GITLAB_HOST}/${GITLAB_GROUP}/${SESSION_TIER}/${SESSION_REPO_NAME}"
    SESSION_LOCAL_PATH="$(resolve_repo_path "$SESSION_REPO_NAME")"   # memory repo
    if [[ -n "$WORK_BASE" ]]; then
        SESSION_WORK_DIR="$WORK_BASE/$SESSION_AID"                   # /home/devops/aid.NNN
    else
        SESSION_WORK_DIR="$SESSION_LOCAL_PATH"
    fi
}

# ── GitLab Repo Operations ───────────────────────────────────

# Resolve a repo's local clone path. Repos live under tier subfolders, so search
# for an existing clone at any depth; else fall back to the tier path for a fresh clone.
resolve_repo_path() {
    local repo_name="$1" found
    found=$(find "$REPOS_DIR" -type d -name "$repo_name" -prune 2>/dev/null | head -1)
    if [[ -n "$found" && -d "${found}/.git" ]]; then
        echo "$found"
    else
        echo "${REPOS_DIR}/${SESSION_TIER}/${repo_name}"
    fi
}

check_gitlab_repo() {
    GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code "${SESSION_REPO_URL}.git" HEAD >/dev/null 2>&1
}

# Clone if not local; fetch+pull (master) if already cloned.
sync_repo() {
    local local_path="$1" current_dir="$PWD"
    if [[ -d "${local_path}/.git" ]]; then
        log "Repo exists — fetch + pull: ${SESSION_REPO_NAME}"
        cd "$local_path"
        GIT_TERMINAL_PROMPT=0 git fetch origin >/dev/null 2>&1
        GIT_TERMINAL_PROMPT=0 git pull origin master --ff-only >/dev/null 2>&1 \
            || GIT_TERMINAL_PROMPT=0 git pull origin master --rebase >/dev/null 2>&1 || true
        cd "$current_dir"
    else
        log "Cloning: ${SESSION_REPO_NAME} → ${local_path}"
        mkdir -p "$(dirname "$local_path")"
        ( umask 002; GIT_TERMINAL_PROMPT=0 git clone --branch master "${SESSION_REPO_URL}.git" "$local_path" )
        cd "$current_dir"
    fi
}

# ── Background, NON-INTERACTIVE commit + push ────────────────
# Stages 08-memory/, commits, pushes to origin master — detached, no prompt.
bg_commit_push() {
    local repo="$1" msg="$2"
    (
        cd "$repo" 2>/dev/null || exit 0
        umask 002
        git add -A 08-memory/ 2>/dev/null
        if git diff --cached --quiet 2>/dev/null; then
            echo "$(date '+%F %T') [$repo] nothing to commit"; exit 0
        fi
        git commit -m "$msg" >/dev/null 2>&1
        if GIT_TERMINAL_PROMPT=0 git push origin master >/dev/null 2>&1; then
            echo "$(date '+%F %T') [$repo] pushed: $msg"
        else
            echo "$(date '+%F %T') [$repo] PUSH FAILED: $msg"
        fi
    ) >>"$PUSH_LOG" 2>&1 &
    disown 2>/dev/null || true
}

# Write a session memory file into 08-memory/long-term/ and trigger bg push.
# $1 = repo path, $2 = optional notes text
save_session_memory() {
    local repo="$1" notes="${2:-}"
    local mdir="${repo}/08-memory/long-term"
    mkdir -p "$mdir" 2>/dev/null
    local ts; ts=$(date '+%Y.%m.%d.%H.%M.%S')
    local file="${mdir}/${SESSION_AID}.${ts}"
    {
        echo "# Memory: ${SESSION_ID}"
        echo "# Saved : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# AID   : ${SESSION_AID}"
        echo "# EID   : ${SESSION_EID:-unknown}"
        echo ""
        if [[ -n "$notes" ]]; then echo "$notes"; else echo "(session marker — no inline notes; see other 08-memory files for agent-written memory)"; fi
    } > "$file"
    echo "$(date '+%F %T') [$repo] memory file: $file" >> "$PUSH_LOG" 2>/dev/null
    bg_commit_push "$repo" "memory(${SESSION_AID}): session notes ${ts}"
}

# Ask the just-ended conversation to (a) summarize ONLY what it did this session
# and (b) self-rate the session's EFFICIENCY 1-10 from the prompts + problem
# difficulty — non-interactively (claude -p --resume). Echoes the full text
# (bullets + a final `EFFICIENCY: N/10 — reason` line). This turns post-session
# memory from a bare marker into a real work log + an efficiency signal that
# `status`/liaison rollups can read. Echoes nothing on any failure (caller falls
# back to the marker). Disable with BNPRS_SESSION_SUMMARY=0.
#   $1 = conversation uuid (the one actually used to launch)   $2 = work dir
generate_session_summary() {
    local uuid="$1" workdir="$2"
    [[ "${BNPRS_SESSION_SUMMARY:-1}" != 0 ]] || return 0
    [[ -n "$uuid" && -n "$CLAUDE_CMD" ]] || return 0
    local prompt="Your session is ending. Respond in exactly two parts, no preamble, no restating these instructions:

1) SUMMARY: 3-8 concise bullet points covering ONLY what was actually accomplished in THIS session — tasks worked on, repos/files changed, decisions made, pending/next steps. If nothing substantive happened, write a single bullet: (no substantive work this session)

2) A final line, by itself, in EXACTLY this format:
EFFICIENCY: N/10 — <≤12-word rationale>
where N is an integer 1-10 rating how efficiently this session solved its problems, judged from the user's prompts and the difficulty/type of problems tackled. Rubric: 1-3 = stuck/thrashing or trivial churn; 4-6 = steady progress with rework; 7-8 = solved the problem cleanly; 9-10 = hard problem solved fast and correctly. Be honest and calibrated; do not inflate."
    local out
    if command -v timeout >/dev/null 2>&1; then
        out=$( cd "$workdir" 2>/dev/null && timeout "${BNPRS_SUMMARY_TIMEOUT:-150}" \
               "$CLAUDE_CMD" --resume "$uuid" -p "$prompt" 2>/dev/null )
    else
        out=$( cd "$workdir" 2>/dev/null && \
               "$CLAUDE_CMD" --resume "$uuid" -p "$prompt" 2>/dev/null )
    fi
    # trim, cap size, drop if effectively empty
    out=$(printf '%s' "$out" | sed -e 's/[[:space:]]*$//' | head -c 8000)
    [[ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ]] || return 0
    printf '%s' "$out"
}

# Pull the integer 1-10 efficiency rating out of a summary blob ('' if none).
parse_efficiency() {
    printf '%s' "$1" \
      | grep -oiE 'EFFICIENCY:[[:space:]]*([0-9]|10)/10' \
      | head -1 | grep -oE '([0-9]|10)/10' | cut -d/ -f1
}

# Append one row to the agent's daily efficiency ledger (CSV, one line per
# session) so per-day ratings are queryable. Columns:
#   date,time,aid,eid,rating,resume_count,rationale
#   $1 = repo path   $2 = rating (1-10)   $3 = rationale text
record_efficiency() {
    local repo="$1" rating="$2" rationale="$3" rcount="${4:-}"
    [[ -n "$rating" ]] || return 0
    local mdir="${repo}/08-memory/long-term"; mkdir -p "$mdir" 2>/dev/null
    local ledger="${mdir}/efficiency.${SESSION_AID}.csv"
    [[ -f "$ledger" ]] || echo "date,time,aid,eid,rating,resume_count,rationale" > "$ledger"
    # sanitize rationale for CSV (strip commas/quotes/newlines)
    rationale=$(printf '%s' "$rationale" | tr '\n' ' ' | tr -d '",' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -c1-120)
    printf '%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date '+%Y-%m-%d')" "$(date '+%H:%M:%S')" "$SESSION_AID" "${SESSION_EID:-unknown}" \
        "$rating" "$rcount" "$rationale" >> "$ledger" 2>/dev/null
    echo "$(date '+%F %T') [$repo] efficiency ${rating}/10" >> "$PUSH_LOG" 2>/dev/null
}

# ── Commands ────────────────────────────────────────────────

cmd_sync_all() {
    ensure_dirs; ensure_git_auth quiet; ensure_aliases
    [[ -d "$REPOS_DIR" ]] || { warn "REPOS_DIR not found: $REPOS_DIR"; return 0; }
    # Discover git repos at ANY depth (tier subfolders → repo → .git).
    local repos=()
    while IFS= read -r gitdir; do repos+=("$(dirname "$gitdir")"); done \
        < <(find "$REPOS_DIR" -type d -name .git -prune 2>/dev/null | sort)
    local total=${#repos[@]}
    [[ $total -gt 0 ]] || { warn "No git repos found in: $REPOS_DIR"; return 0; }
    log "Syncing ${total} repos in: $REPOS_DIR"; echo ""
    local ok=0 fail=0 current_dir="$PWD"
    for repo_path in "${repos[@]}"; do
        local name; name=$(basename "$repo_path")
        cd "$repo_path"
        if GIT_TERMINAL_PROMPT=0 git fetch origin >/dev/null 2>&1 \
           && GIT_TERMINAL_PROMPT=0 git pull origin master --ff-only >/dev/null 2>&1; then
            ok=$((ok+1)); printf "  ${GREEN}✓${NC} %s\n" "$name"
        elif GIT_TERMINAL_PROMPT=0 git pull origin master --rebase >/dev/null 2>&1; then
            ok=$((ok+1)); printf "  ${GREEN}✓${NC} %s (rebased)\n" "$name"
        else
            fail=$((fail+1)); printf "  ${RED}✗${NC} %s\n" "$name"
        fi
        cd "$current_dir"
    done
    echo ""
    if [[ $fail -eq 0 ]]; then log "Sync complete: ${ok}/${total} up to date"
    else warn "Sync complete: ${ok} OK, ${fail} failed"; fi
}

cmd_init() {
    ensure_dirs
    ensure_git_auth
    ensure_aliases loud
    log "Initialized BNPRS session dirs"
    log "  Sessions : $SESSIONS_DIR"
    log "  Repos    : $REPOS_DIR"
    log "  AID map  : $AID_MAP"
    log "Session ID format: AID.<NNN>  e.g. AID.001"
    echo ""
    cmd_sync_all
}

cmd_sync() {
    local sid="${1:?Session ID required (e.g., AID.001)}"
    parse_session_id "$sid"; ensure_dirs; ensure_git_auth quiet
    log "Checking GitLab: ${SESSION_REPO_URL}"
    if check_gitlab_repo; then
        sync_repo "$SESSION_LOCAL_PATH"; log "Sync complete: ${SESSION_LOCAL_PATH}"
    else
        err "Repo not found/inaccessible: ${SESSION_REPO_URL}"; exit 1
    fi
}

cmd_start() {
    local sid="${1:?Session ID required (e.g., AID.001)}"
    parse_session_id "$sid"; ensure_dirs; ensure_git_auth quiet; ensure_aliases
    echo "$(date '+%F %T') start ${SESSION_ID} (EID ${SESSION_EID:-unknown}) work=${SESSION_WORK_DIR}" >> "$PUSH_LOG" 2>/dev/null

    if check_gitlab_repo; then sync_repo "$SESSION_LOCAL_PATH" >>"$PUSH_LOG" 2>&1
    else err "Repo not found/inaccessible: ${SESSION_REPO_URL}"; exit 1; fi

    # Ensure the agent's working home exists; seed identity from the repo if fresh,
    # and link its 08-memory to the memory repo so agent memory writes are pushable.
    if [[ ! -d "$SESSION_WORK_DIR" ]]; then
        mkdir -p "$SESSION_WORK_DIR"
        [[ -f "$SESSION_LOCAL_PATH/CLAUDE.md" ]] && cp "$SESSION_LOCAL_PATH/CLAUDE.md" "$SESSION_WORK_DIR/" 2>/dev/null || true
        [[ -f "$SESSION_LOCAL_PATH/agent.yaml" ]] && cp "$SESSION_LOCAL_PATH/agent.yaml" "$SESSION_WORK_DIR/" 2>/dev/null || true
    fi
    if [[ "$SESSION_WORK_DIR" != "$SESSION_LOCAL_PATH" && ! -e "$SESSION_WORK_DIR/08-memory" ]]; then
        ln -s "$SESSION_LOCAL_PATH/08-memory" "$SESSION_WORK_DIR/08-memory" 2>/dev/null || true
    fi

    # Load latest long-term memory (most recent file) for context
    local repo_memory="" mdir="${SESSION_LOCAL_PATH}/08-memory/long-term"
    if [[ -d "$mdir" ]]; then
        local latest; latest=$(ls -t "${mdir}/${SESSION_AID}."* 2>/dev/null | head -1 || true)
        [[ -n "$latest" && -f "$latest" ]] && repo_memory=$(cat "$latest")
    fi

    # Session meta
    local meta_file; meta_file=$(session_meta_file "$SESSION_ID"); local is_new=false
    if [[ ! -f "$meta_file" ]]; then
        is_new=true
        cat > "$meta_file" <<EOF
session_id=${SESSION_ID}
aid=${SESSION_AID}
eid=${SESSION_EID}
repo_name=${SESSION_REPO_NAME}
repo_local=${SESSION_LOCAL_PATH}
work_dir=${SESSION_WORK_DIR}
claude_uuid=$(generate_uuid)
created=$(date '+%Y-%m-%d %H:%M:%S')
last_used=$(date '+%Y-%m-%d %H:%M:%S')
resume_count=0
EOF
    fi
    local claude_uuid resume_count
    claude_uuid=$(grep "^claude_uuid=" "$meta_file" | cut -d= -f2)
    resume_count=$(grep "^resume_count=" "$meta_file" | cut -d= -f2)

    if ! $is_new; then
        SED_I "s/^last_used=.*/last_used=$(date '+%Y-%m-%d %H:%M:%S')/" "$meta_file"
        resume_count=$((resume_count+1))
        SED_I "s/^resume_count=.*/resume_count=${resume_count}/" "$meta_file"
    fi

    local resume_prompt
    if [[ -n "$repo_memory" ]]; then
        resume_prompt="You are resuming agent session ${SESSION_ID} (resume #${resume_count}).
AID: ${SESSION_AID} | EID: ${SESSION_EID:-unknown}
Repo : ${SESSION_REPO_URL}

--- LATEST LONG-TERM MEMORY ---
${repo_memory}
--- END MEMORY ---

Acknowledge context and ask what to work on next."
    else
        resume_prompt="Starting agent session ${SESSION_ID}.
AID: ${SESSION_AID} | EID: ${SESSION_EID:-unknown}
Repo : ${SESSION_REPO_URL}
No prior long-term memory found. What would you like to work on?"
    fi

    # Identity reminder — injected on EVERY launch (incl. --resume). A resumed
    # transcript may pre-date a slot remap and still call itself by the OLD AID
    # (e.g. an agent remapped aid.034→aid.033 keeps saying "I am aid.034"). This
    # one line re-anchors the agent to its CURRENT slot so it doesn't mis-identify.
    local id_reminder="IDENTITY: your current session is ${SESSION_ID} (EID ${SESSION_EID:-unknown}), memory repo ${SESSION_REPO_NAME}. If earlier turns in this conversation refer to a different aid.NNN, that is pre-remap history — use ${SESSION_ID} from now on."

    # Launch Claude from inside the agent's WORK HOME (resumes the old conversation,
    # whose Claude history is keyed to this path). Memory writes go via the 08-memory symlink.
    # Track the conversation uuid actually used, so the post-session summary resumes it.
    local current_dir="$PWD" effective_uuid="$claude_uuid"
    cd "$SESSION_WORK_DIR"
    if ! $is_new && [[ -n "$claude_uuid" ]]; then
        $CLAUDE_CMD --resume "$claude_uuid" --append-system-prompt "$id_reminder" 2>/dev/null || {
            echo "$(date '+%F %T') resume $claude_uuid expired; fresh session ${SESSION_ID}" >> "$PUSH_LOG" 2>/dev/null
            local new_uuid; new_uuid=$(generate_uuid)
            SED_I "s/^claude_uuid=.*/claude_uuid=${new_uuid}/" "$meta_file"
            effective_uuid="$new_uuid"
            $CLAUDE_CMD --session-id "$new_uuid" --name "bnprs-${SESSION_ID}" --append-system-prompt "$resume_prompt"
        }
    else
        $CLAUDE_CMD --session-id "$claude_uuid" --name "bnprs-${SESSION_ID}" --append-system-prompt "$resume_prompt"
    fi
    cd "$current_dir"

    # Post-session: ask the conversation to summarize what it did + self-rate
    # efficiency (1-10). Save the summary as the memory body (falls back to a
    # marker if unavailable), append the rating to the per-agent daily ledger,
    # then bg push. SILENT — no terminal output.
    local session_summary eff_rating eff_reason
    session_summary=$(generate_session_summary "$effective_uuid" "$SESSION_WORK_DIR")
    eff_rating=$(parse_efficiency "$session_summary")
    eff_reason=$(printf '%s' "$session_summary" | grep -iE 'EFFICIENCY:' | head -1 | sed -E 's/.*[0-9]+\/10[[:space:]—-]*//')
    [[ -n "$eff_rating" ]] && record_efficiency "$SESSION_LOCAL_PATH" "$eff_rating" "$eff_reason" "${resume_count:-}" >/dev/null 2>&1
    save_session_memory "$SESSION_LOCAL_PATH" "$session_summary" >/dev/null 2>&1
}

cmd_save_memory() {
    local sid="${1:?Session ID required (e.g., AID.001)}"; shift || true
    parse_session_id "$sid"; ensure_dirs
    # Notes: from remaining args, or piped stdin if available; never blocks.
    local notes="$*"
    if [[ -z "$notes" && ! -t 0 ]]; then notes="$(cat)"; fi
    [[ -d "${SESSION_LOCAL_PATH}/.git" ]] || { check_gitlab_repo && sync_repo "$SESSION_LOCAL_PATH"; }
    save_session_memory "$SESSION_LOCAL_PATH" "$notes"
    log "Saved memory for ${SESSION_ID}; committing + pushing in background (see $PUSH_LOG)."
}

cmd_list() {
    ensure_dirs
    echo ""; echo -e "${BOLD}BNPRS Sessions${NC}"
    printf "  ${BOLD}%-10s %-8s %-22s %s${NC}\n" "AID" "EID" "Last Used" "Resumes"
    local found=0
    for meta in "$SESSIONS_DIR"/*.meta; do
        [[ -f "$meta" ]] || continue; found=1
        local aid eid lu rc
        aid=$(grep "^aid=" "$meta" | cut -d= -f2)
        eid=$(grep "^eid=" "$meta" | cut -d= -f2)
        lu=$(grep  "^last_used=" "$meta" | cut -d= -f2-)
        rc=$(grep  "^resume_count=" "$meta" | cut -d= -f2)
        printf "  ${GREEN}%-10s${NC} %-8s %-22s %s\n" "$aid" "${eid:-—}" "$lu" "$rc"
    done
    [[ $found -eq 0 ]] && echo "  No sessions found."
    echo ""
}

cmd_status() {
    local sid="${1:?Session ID required (e.g., AID.001)}"
    parse_session_id "$sid"
    local meta_file; meta_file=$(session_meta_file "$SESSION_ID")
    [[ -f "$meta_file" ]] || { err "Session '${SESSION_ID}' not found"; exit 1; }
    echo ""; echo -e "${BOLD}Session: ${SESSION_ID}${NC}"; sed 's/^/  /' "$meta_file"; echo ""
    local mdir="${SESSION_LOCAL_PATH}/08-memory/long-term"
    if [[ -d "$mdir" ]]; then
        echo -e "${BOLD}Long-term memory files (${SESSION_AID}):${NC}"
        ls -lt "${mdir}/${SESSION_AID}."* 2>/dev/null | awk '{print "  "$NF}' | head -10 || echo "  None"
    fi
    echo ""
}

cmd_delete() {
    local sid="${1:?Session ID required (e.g., AID.001)}"
    parse_session_id "$sid"
    local meta_file; meta_file=$(session_meta_file "$SESSION_ID")
    [[ -f "$meta_file" ]] || { err "Session '${SESSION_ID}' not found"; exit 1; }
    read -rp "Delete LOCAL session meta for ${SESSION_ID}? (y/n): " c
    [[ "$c" == "y" ]] && { rm -f "$meta_file"; log "Deleted local meta for ${SESSION_ID} (repo memory on GitLab preserved)"; }
}

# Report session efficiency ratings from the per-agent ledgers
#   08-memory/long-term/efficiency.<aid>.csv  (date,time,aid,eid,rating,resume_count,rationale)
# Usage:
#   efficiency             → today's ratings across all agents + team average
#   efficiency all         → same as above
#   efficiency AID.NNN     → that agent's full rating history + its average
#   efficiency YYYY-MM-DD  → that day's ratings across all agents + team average
# CSV-safe: rationale is taken as everything after the 6th comma (commas in the
# text never truncate it). Reads ledgers under REPOS_DIR (memory-repo clones).
cmd_efficiency() {
    ensure_dirs
    local arg="${1:-}" want_aid="" want_date=""
    if [[ "$arg" =~ ^[Aa][Ii][Dd]\.?[0-9]{1,3}$ || "$arg" =~ ^[0-9]{1,3}$ ]]; then
        parse_session_id "$arg"; want_aid="$SESSION_AID"
    elif [[ "$arg" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        want_date="$arg"
    elif [[ -n "$arg" && "$arg" != "all" ]]; then
        err "Usage: efficiency [AID.NNN | YYYY-MM-DD | all]"; exit 1
    fi
    [[ -n "$want_aid" || -n "$want_date" ]] || want_date="$(date '+%Y-%m-%d')"

    # collect matching rows from all ledgers via awk (CSV field 7+ = rationale)
    local rows
    rows=$(find "$REPOS_DIR" -type f -name 'efficiency.aid.*.csv' 2>/dev/null -print0 \
      | xargs -0 awk -F, -v wa="$want_aid" -v wd="$want_date" '
          FNR==1 { next }                                  # skip header
          NF<7 { next }
          { aid=$3; date=$1; rate=$5;
            reason=$7; for(i=8;i<=NF;i++) reason=reason","$i;
            if (wa!="" && aid!=wa) next;
            if (wd!="" && date!=wd) next;
            printf "%s\t%s\t%s\t%s\n", rate, aid, date, reason }' 2>/dev/null)

    if [[ -z "$rows" ]]; then
        warn "No efficiency data for ${want_aid:-$want_date}."; return 0
    fi

    echo ""
    if [[ -n "$want_aid" ]]; then
        echo -e "${BOLD}Efficiency history — ${want_aid}${NC}"
        printf "  ${BOLD}%-5s %-12s %s${NC}\n" "Rate" "Date" "Rationale"
        printf '%s\n' "$rows" | sort -t$'\t' -k3,3 \
          | awk -F'\t' '{printf "  %-5s %-12s %s\n",$1"/10",$3,$4}'
    else
        echo -e "${BOLD}Team efficiency — ${want_date}${NC}"
        printf "  ${BOLD}%-5s %-10s %s${NC}\n" "Rate" "AID" "Rationale"
        printf '%s\n' "$rows" | sort -t$'\t' -k1,1nr -k2,2 \
          | awk -F'\t' '{printf "  %-5s %-10s %s\n",$1"/10",$2,$4}'
    fi
    # average over numeric ratings
    printf '%s\n' "$rows" | awk -F'\t' '
        $1 ~ /^[0-9]+$/ { s+=$1; n++ }
        END { if(n) printf "\n  Sessions: %d   Average: %.2f/10\n\n", n, s/n;
              else  printf "\n  No numeric ratings.\n\n" }'
}

# ── Main ────────────────────────────────────────────────────
case "${1:-help}" in
    init)             cmd_init ;;
    sync-all|sa)      cmd_sync_all ;;
    start|s)          cmd_start       "${2:-}" ;;
    sync)             cmd_sync        "${2:-}" ;;
    list|ls)          cmd_list ;;
    status|st)        cmd_status      "${2:-}" ;;
    delete|rm)        cmd_delete      "${2:-}" ;;
    save-memory|sm)   shift; cmd_save_memory "$@" ;;
    efficiency|eff)   cmd_efficiency  "${2:-}" ;;
    help|*)
        echo ""
        echo -e "${BOLD}BNPRS Session Manager${NC} for Claude Code"
        echo -e "Session ID:  ${CYAN}AID.<NNN>${NC}  e.g. AID.001  (also aid.001 | 001)"
        echo ""
        echo "Commands:"
        echo "  init                       Setup + sync-all"
        echo "  sync-all                   Fetch + pull all repos in REPOS_DIR"
        echo "  start  AID.NNN             Start or resume an agent session"
        echo "  sync   AID.NNN             Sync one repo"
        echo "  list                       List local sessions"
        echo "  status AID.NNN             Session details + memory files"
        echo "  delete AID.NNN             Delete local session meta"
        echo "  save-memory AID.NNN [text] Save memory (non-interactive) + bg push"
        echo "  efficiency [AID|DATE|all]  Efficiency ratings (default: today, all agents) + average"
        echo ""
        echo "Repos dir : $REPOS_DIR"
        echo "AID map   : $AID_MAP"
        echo ""
        ;;
esac
