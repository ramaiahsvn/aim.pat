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

# Ensure a PERSISTENT git credential helper exists (Linux/EC2). Without this, a
# wiped devops gitconfig leaves info_bnprs with nothing backing it and every
# non-interactive clone/pull/push 401s → GitLab reports the private repo as
# "not found". Idempotent and self-healing; NEVER hardcodes a secret. If
# BNPRS_GIT_PASSWORD is set AND nothing is stored yet, it primes the store once
# (the value is read from the env, never written into this script or any repo).
#   $1 = "quiet" to suppress info/warn output (used on the hot sync/start paths).
ensure_git_auth() {
    local quiet="${1:-}"
    [[ "$(uname)" == "Darwin" ]] && return 0          # macOS: use system keychain helper
    [[ -n "$GIT_REMOTE_USER" ]] || return 0
    # 1) make sure a persistent 'store' helper is configured (additive, idempotent)
    if ! git config --global --get-all credential.helper 2>/dev/null | grep -qx store; then
        git config --global --add credential.helper store
        [[ "$quiet" == quiet ]] || log "Configured persistent git credential helper: store"
    fi
    # 2) if nothing is stored for the host yet, optionally prime from env (one-time)
    local cred_file="$HOME/.git-credentials"
    if ! grep -q "//${GIT_REMOTE_USER}:.*@${GITLAB_HOST}" "$cred_file" 2>/dev/null; then
        if [[ -n "${BNPRS_GIT_PASSWORD:-}" ]]; then
            printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' \
                "$GITLAB_HOST" "$GIT_REMOTE_USER" "$BNPRS_GIT_PASSWORD" | git credential approve
            [[ -f "$cred_file" ]] && chmod 600 "$cred_file"
            [[ "$quiet" == quiet ]] || log "Primed git credential for ${GIT_REMOTE_USER}@${GITLAB_HOST} (store)"
        elif [[ "$quiet" != quiet ]]; then
            warn "No stored git credential for ${GIT_REMOTE_USER}@${GITLAB_HOST}."
            warn "Prime it once:  set BNPRS_GIT_PASSWORD and re-run 'init', or run:"
            warn "  printf 'protocol=https\\nhost=${GITLAB_HOST}\\nusername=${GIT_REMOTE_USER}\\npassword=<PW>\\n\\n' | git credential approve"
        fi
    fi
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

# ── Commands ────────────────────────────────────────────────

cmd_sync_all() {
    ensure_dirs; ensure_git_auth quiet
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
    parse_session_id "$sid"; ensure_dirs; ensure_git_auth quiet
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

    # Launch Claude from inside the agent's WORK HOME (resumes the old conversation,
    # whose Claude history is keyed to this path). Memory writes go via the 08-memory symlink.
    local current_dir="$PWD"
    cd "$SESSION_WORK_DIR"
    if ! $is_new && [[ -n "$claude_uuid" ]]; then
        $CLAUDE_CMD --resume "$claude_uuid" 2>/dev/null || {
            echo "$(date '+%F %T') resume $claude_uuid expired; fresh session ${SESSION_ID}" >> "$PUSH_LOG" 2>/dev/null
            local new_uuid; new_uuid=$(generate_uuid)
            SED_I "s/^claude_uuid=.*/claude_uuid=${new_uuid}/" "$meta_file"
            $CLAUDE_CMD --session-id "$new_uuid" --name "bnprs-${SESSION_ID}" --append-system-prompt "$resume_prompt"
        }
    else
        $CLAUDE_CMD --session-id "$claude_uuid" --name "bnprs-${SESSION_ID}" --append-system-prompt "$resume_prompt"
    fi
    cd "$current_dir"

    # Post-session: auto-save memory + background push. SILENT — no terminal output.
    save_session_memory "$SESSION_LOCAL_PATH" "" >/dev/null 2>&1
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
        echo ""
        echo "Repos dir : $REPOS_DIR"
        echo "AID map   : $AID_MAP"
        echo ""
        ;;
esac
