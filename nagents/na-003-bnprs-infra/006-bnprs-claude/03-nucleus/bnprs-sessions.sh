#!/bin/bash
# ============================================================
#  BNPRS Session Manager for Claude Code CLI
#  Session ID format:  E1026-aid.001
# ============================================================
#
#  Usage:
#    ./bnprs-sessions.sh init
#    ./bnprs-sessions.sh start E1026-aid.001    # Start or resume
#    ./bnprs-sessions.sh sync  E1026-aid.001    # Sync repo only
#    ./bnprs-sessions.sh list                   # List all sessions
#    ./bnprs-sessions.sh status E1026-aid.001   # Session details
#    ./bnprs-sessions.sh delete E1026-aid.001   # Delete local session
#    ./bnprs-sessions.sh save-memory E1026-aid.001
#
#  Session ID breakdown:
#    E1026      — employee HR ID
#    aid.001    — agent ID (AID-001 from na-008-bnprs-team)
#
#  Env vars (override defaults):
#    GITLAB_PAT        GitLab personal access token (required)
#    GITLAB_HOST       default: gitlab.bnprs.ai
#    GITLAB_GROUP      default: aim1001
#    REPOS_DIR         local clone base dir  default: ~/aim1001
#    CLAUDE_CMD        claude binary          default: claude
#
# ============================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────
SESSIONS_DIR="$HOME/.claude/bnprs-sessions"
MEMORY_DIR="$HOME/.claude/bnprs-memory"
REPOS_DIR="${BNPRS_REPOS_DIR:-$HOME/aim1001}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.bnprs.ai}"
GITLAB_GROUP="${GITLAB_GROUP:-aim1001}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
PROJECT_ROOT="${BNPRS_PROJECT_ROOT:-$(pwd)}"

# macOS/Linux-compatible sed -i
if [[ "$(uname)" == "Darwin" ]]; then
    SED_I() { sed -i '' "$@"; }
else
    SED_I() { sed -i "$@"; }
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────
log()  { echo -e "${GREEN}[bnprs]${NC} $*"; }
warn() { echo -e "${YELLOW}[bnprs]${NC} $*"; }
err()  { echo -e "${RED}[bnprs]${NC} $*" >&2; }

ensure_dirs() {
    mkdir -p "$SESSIONS_DIR" "$MEMORY_DIR" "$REPOS_DIR"
}

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || uuidgen 2>/dev/null \
        || echo "$(od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-4"substr($5,2)"-"substr($6,1,1)substr($6,2)"-"$7$8$9}')"
}

session_meta_file()   { echo "$SESSIONS_DIR/${1//\//_}.meta"; }
session_memory_file() { echo "$MEMORY_DIR/${1//\//_}.md"; }

# ── Session ID Parsing ───────────────────────────────────────
# Input:   E1026-aid.001
# Exports: SESSION_EID, SESSION_AID, SESSION_AID_NUM,
#          SESSION_REPO_NAME, SESSION_REPO_URL, SESSION_LOCAL_PATH

parse_session_id() {
    local full_sid="$1"

    # Validate format: E<digits>-aid.<3digits>
    if ! echo "$full_sid" | grep -qE '^E[0-9]+-aid\.[0-9]{3}$'; then
        err "Invalid session ID: '${full_sid}'"
        err "Expected format:  E<number>-aid.<NNN>   e.g.  E1026-aid.001"
        exit 1
    fi

    SESSION_EID="${full_sid%%-*}"                         # E1026
    SESSION_AID="${full_sid#*-}"                          # aid.001
    SESSION_AID_NUM="${SESSION_AID#*.}"                   # 001
    SESSION_REPO_NAME="${GITLAB_GROUP}.${SESSION_AID}"    # aim1001.aid.001
    SESSION_REPO_URL="https://${GITLAB_HOST}/${GITLAB_GROUP}/${SESSION_REPO_NAME}"
    SESSION_LOCAL_PATH="${REPOS_DIR}/${SESSION_REPO_NAME}"
}

# ── GitLab Repo Operations ───────────────────────────────────

require_gitlab_pat() {
    if [[ -z "${GITLAB_PAT:-}" ]]; then
        err "GITLAB_PAT is not set."
        err "Add to your shell:  export GITLAB_PAT='glpat-xxxxxxxxxxxx'"
        exit 1
    fi
}

# Returns 0 if GitLab repo exists and is accessible
check_gitlab_repo() {
    local repo_name="$1"
    require_gitlab_pat
    # URL-encode the path separator
    local encoded_path
    encoded_path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${GITLAB_GROUP}/${repo_name}', safe=''))" 2>/dev/null \
        || echo "${GITLAB_GROUP}%2F${repo_name}")
    local api_url="https://${GITLAB_HOST}/api/v4/projects/${encoded_path}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 10 \
        -H "PRIVATE-TOKEN: ${GITLAB_PAT}" \
        "$api_url")
    [[ "$http_code" == "200" ]]
}

# Clone if not local; fetch+pull if already cloned
sync_repo() {
    local repo_name="$1"
    local local_path="$2"
    local current_dir="$PWD"
    require_gitlab_pat

    local authed_url="https://oauth2:${GITLAB_PAT}@${GITLAB_HOST}/${GITLAB_GROUP}/${repo_name}.git"
    local clean_url="https://${GITLAB_HOST}/${GITLAB_GROUP}/${repo_name}.git"

    if [[ -d "${local_path}/.git" ]]; then
        log "Repo exists locally — fetching and pulling: ${repo_name}"
        cd "$local_path"
        # Temporarily set authed URL for fetch/pull
        git remote set-url origin "$authed_url"
        git fetch origin
        git pull origin master --ff-only 2>/dev/null \
            || git pull origin master --rebase
        git remote set-url origin "$clean_url"
        cd "$current_dir"
    else
        log "Cloning repo: ${repo_name} → ${local_path}"
        mkdir -p "$(dirname "$local_path")"
        git clone --branch master "$authed_url" "$local_path"
        # Restore clean URL (no token in .git/config)
        cd "$local_path"
        git remote set-url origin "$clean_url"
        cd "$current_dir"
    fi
}

# ── Write memory file to repo and push ──────────────────────

write_memory_to_repo() {
    local full_sid="$1"
    local content="$2"
    parse_session_id "$full_sid"

    local memory_dir="${SESSION_LOCAL_PATH}/08-memory"
    mkdir -p "$memory_dir"

    # Filename: aid.001.2026.05.28.15.30.45
    local ts
    ts=$(date '+%Y.%m.%d.%H.%M.%S')
    local filename="${SESSION_AID}.${ts}"
    local filepath="${memory_dir}/${filename}"

    cat > "$filepath" << EOF
# Memory: ${full_sid}
# Saved : $(date '+%Y-%m-%d %H:%M:%S')
# EID   : ${SESSION_EID}
# AID   : ${SESSION_AID}

${content}
EOF

    log "Memory file: ${filepath}"

    local current_dir="$PWD"
    cd "$SESSION_LOCAL_PATH"

    git add "08-memory/${filename}"
    git commit -m "memory(${SESSION_AID}): session notes ${ts}

Employee : ${SESSION_EID}
Session  : ${full_sid}"

    # Push with authed URL, then restore clean URL
    require_gitlab_pat
    local authed_url="https://oauth2:${GITLAB_PAT}@${GITLAB_HOST}/${GITLAB_GROUP}/${SESSION_REPO_NAME}.git"
    local clean_url="https://${GITLAB_HOST}/${GITLAB_GROUP}/${SESSION_REPO_NAME}.git"
    git remote set-url origin "$authed_url"
    git push origin master
    git remote set-url origin "$clean_url"

    cd "$current_dir"
    log "Pushed → ${SESSION_REPO_URL}/-/blob/master/08-memory/${filename}"
}

# ── Commands ────────────────────────────────────────────────

cmd_init() {
    ensure_dirs
    log "Initialized BNPRS session directories"
    log "  Sessions : $SESSIONS_DIR"
    log "  Memory   : $MEMORY_DIR"
    log "  Repos    : $REPOS_DIR"
    echo ""
    log "Session ID format:  E<number>-aid.<NNN>   e.g. E1026-aid.001"
    log "GitLab base       : https://${GITLAB_HOST}/${GITLAB_GROUP}"
    echo ""
    log "Make sure GITLAB_PAT is exported in your shell."
    echo ""
    log "${BOLD}Usage:${NC}"
    echo "  ./bnprs-sessions.sh start E1026-aid.001"
    echo "  ./bnprs-sessions.sh save-memory E1026-aid.001"
}

cmd_sync() {
    local full_sid="${1:?Session ID required (e.g., E1026-aid.001)}"
    parse_session_id "$full_sid"
    ensure_dirs

    log "Checking GitLab: ${SESSION_REPO_URL}"
    if check_gitlab_repo "$SESSION_REPO_NAME"; then
        log "Repo found — syncing..."
        sync_repo "$SESSION_REPO_NAME" "$SESSION_LOCAL_PATH"
        log "Sync complete: ${SESSION_LOCAL_PATH}"
    else
        err "Repo not found: ${SESSION_REPO_URL}"
        err "Ask admin to create '${SESSION_REPO_NAME}' in group '${GITLAB_GROUP}'"
        exit 1
    fi
}

cmd_start() {
    local full_sid="${1:?Session ID required (e.g., E1026-aid.001)}"
    parse_session_id "$full_sid"
    ensure_dirs

    echo ""
    log "Session  : ${full_sid}"
    log "Employee : ${SESSION_EID}   AID: ${SESSION_AID}"
    log "Repo     : ${SESSION_REPO_URL}"
    echo ""

    # ── Check GitLab repo, sync local clone ─────────────────
    log "Checking GitLab repo..."
    if check_gitlab_repo "$SESSION_REPO_NAME"; then
        sync_repo "$SESSION_REPO_NAME" "$SESSION_LOCAL_PATH"
    else
        err "Repo not found: ${SESSION_REPO_URL}"
        err "Ask admin to create '${SESSION_REPO_NAME}' in group '${GITLAB_GROUP}'"
        exit 1
    fi

    # ── Load latest memory from repo ────────────────────────
    local repo_memory=""
    local memory_dir="${SESSION_LOCAL_PATH}/08-memory"
    if [[ -d "$memory_dir" ]]; then
        local latest_mem
        latest_mem=$(ls -t "${memory_dir}/${SESSION_AID}."* 2>/dev/null | head -1 || true)
        if [[ -n "$latest_mem" && -f "$latest_mem" ]]; then
            repo_memory=$(cat "$latest_mem")
            log "Loaded memory: $(basename "$latest_mem")"
        fi
    fi
    echo ""

    # ── Session meta ─────────────────────────────────────────
    local meta_file
    meta_file=$(session_meta_file "$full_sid")
    local is_new=false

    if [[ ! -f "$meta_file" ]]; then
        is_new=true
        local claude_uuid
        claude_uuid=$(generate_uuid)
        cat > "$meta_file" << EOF
session_id=${full_sid}
eid=${SESSION_EID}
aid=${SESSION_AID}
repo_name=${SESSION_REPO_NAME}
repo_local=${SESSION_LOCAL_PATH}
claude_uuid=${claude_uuid}
created=$(date '+%Y-%m-%d %H:%M:%S')
last_used=$(date '+%Y-%m-%d %H:%M:%S')
resume_count=0
EOF
    fi

    local claude_uuid last_used resume_count
    claude_uuid=$(grep   "^claude_uuid="   "$meta_file" | cut -d= -f2)
    last_used=$(grep     "^last_used="     "$meta_file" | cut -d= -f2-)
    resume_count=$(grep  "^resume_count="  "$meta_file" | cut -d= -f2)

    # ── Banner ───────────────────────────────────────────────
    if $is_new; then
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}New Session: ${full_sid}${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Resuming: ${full_sid}  (resume #${resume_count})${NC}"
        echo -e "${CYAN}║${NC}  Last active: ${last_used:-unknown}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        SED_I "s/^last_used=.*/last_used=$(date '+%Y-%m-%d %H:%M:%S')/" "$meta_file"
        local new_count=$(( resume_count + 1 ))
        SED_I "s/^resume_count=.*/resume_count=${new_count}/" "$meta_file"
        resume_count="$new_count"
    fi
    echo ""

    # ── Build system prompt ──────────────────────────────────
    local resume_prompt
    if [[ -n "$repo_memory" ]]; then
        resume_prompt="You are resuming session ${full_sid} (resume #${resume_count}).
Employee: ${SESSION_EID} | Agent ID: ${SESSION_AID}
Repo    : ${SESSION_REPO_URL}
Local   : ${SESSION_LOCAL_PATH}

--- LATEST SESSION MEMORY ---
${repo_memory}
--- END MEMORY ---

Acknowledge the context and ask what to work on next."
    else
        resume_prompt="Starting session ${full_sid}.
Employee: ${SESSION_EID} | Agent ID: ${SESSION_AID}
Repo    : ${SESSION_REPO_URL}
No prior memory found. What would you like to work on?"
    fi

    # ── Launch Claude ────────────────────────────────────────
    if ! $is_new && [[ -n "$claude_uuid" ]]; then
        log "Attempting to resume Claude session: ${claude_uuid}"
        $CLAUDE_CMD --resume "$claude_uuid" 2>/dev/null \
            || {
                warn "Previous Claude session expired — starting fresh with memory..."
                local new_uuid
                new_uuid=$(generate_uuid)
                SED_I "s/^claude_uuid=.*/claude_uuid=${new_uuid}/" "$meta_file"
                $CLAUDE_CMD --session-id "$new_uuid" \
                    --name "bnprs-${full_sid}" \
                    --append-system-prompt "$resume_prompt"
            }
    else
        $CLAUDE_CMD --session-id "$claude_uuid" --name "bnprs-${full_sid}"
    fi

    # ── Post-session: offer to save memory ───────────────────
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Session ${full_sid} ended.${NC}"
    echo ""
    read -rp "Save session notes to repo? (y/n): " save_notes
    if [[ "$save_notes" == "y" ]]; then
        echo ""
        echo "Enter session notes (Ctrl+D when done):"
        echo "──────────────────────────────────────────"
        local notes
        notes=$(cat)
        write_memory_to_repo "$full_sid" "$notes"
    fi
}

cmd_list() {
    ensure_dirs
    echo ""
    echo -e "${BOLD}BNPRS Sessions${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  ${BOLD}%-22s %-10s %-10s %-22s %s${NC}\n" "Session ID" "EID" "AID" "Last Used" "Resumes"
    echo -e "  ──────────────────────────────────────────────────────────────────"

    local found=0
    for meta in "$SESSIONS_DIR"/*.meta; do
        [[ -f "$meta" ]] || continue
        found=1
        local sid eid aid last_used resume_count
        sid=$(grep          "^session_id="   "$meta" | cut -d= -f2)
        eid=$(grep          "^eid="          "$meta" | cut -d= -f2)
        aid=$(grep          "^aid="          "$meta" | cut -d= -f2)
        last_used=$(grep    "^last_used="    "$meta" | cut -d= -f2-)
        resume_count=$(grep "^resume_count=" "$meta" | cut -d= -f2)
        printf "  ${GREEN}%-22s${NC} %-10s %-10s %-22s %s\n" \
            "$sid" "$eid" "$aid" "$last_used" "$resume_count"
    done

    [[ $found -eq 0 ]] && echo "  No sessions found."
    echo ""
}

cmd_status() {
    local full_sid="${1:?Session ID required (e.g., E1026-aid.001)}"
    parse_session_id "$full_sid"
    local meta_file
    meta_file=$(session_meta_file "$full_sid")

    [[ -f "$meta_file" ]] || { err "Session '${full_sid}' not found"; exit 1; }

    echo ""
    echo -e "${BOLD}Session: ${full_sid}${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sed 's/^/  /' "$meta_file"
    echo ""

    # List repo memory files for this AID
    local memory_dir="${SESSION_LOCAL_PATH}/08-memory"
    if [[ -d "$memory_dir" ]]; then
        echo -e "${BOLD}Repo memory files (${SESSION_AID}):${NC}"
        ls -lt "${memory_dir}/${SESSION_AID}."* 2>/dev/null \
            | awk '{print "  " $NF}' \
            | head -10 \
            || echo "  None"
    else
        echo -e "${YELLOW}  Repo not cloned yet. Run: sync ${full_sid}${NC}"
    fi
    echo ""
}

cmd_delete() {
    local full_sid="${1:?Session ID required (e.g., E1026-aid.001)}"
    local meta_file
    meta_file=$(session_meta_file "$full_sid")
    local mem_file
    mem_file=$(session_memory_file "$full_sid")

    [[ -f "$meta_file" ]] || { err "Session '${full_sid}' not found"; exit 1; }

    read -rp "Delete local session meta for ${full_sid}? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm -f "$meta_file" "$mem_file"
        log "Local session data deleted for ${full_sid}"
        log "Note: repo memory at ${SESSION_LOCAL_PATH}/08-memory/ is preserved on GitLab"
    fi
}

cmd_save_memory() {
    local full_sid="${1:?Session ID required (e.g., E1026-aid.001)}"
    parse_session_id "$full_sid"
    ensure_dirs

    # Sync repo first so we push on top of latest
    log "Syncing repo before saving..."
    if check_gitlab_repo "$SESSION_REPO_NAME"; then
        sync_repo "$SESSION_REPO_NAME" "$SESSION_LOCAL_PATH"
    else
        err "Repo not found: ${SESSION_REPO_URL}"
        exit 1
    fi

    echo ""
    echo "Enter memory content (Ctrl+D when done):"
    echo "──────────────────────────────────────────"
    local content
    content=$(cat)

    write_memory_to_repo "$full_sid" "$content"
}

# ── Main ────────────────────────────────────────────────────

case "${1:-help}" in
    init)           cmd_init ;;
    start|s)        cmd_start "${2:-}" ;;
    sync)           cmd_sync  "${2:-}" ;;
    list|ls)        cmd_list ;;
    status|st)      cmd_status    "${2:-}" ;;
    delete|rm)      cmd_delete    "${2:-}" ;;
    save-memory|sm) cmd_save_memory "${2:-}" ;;
    help|*)
        echo ""
        echo -e "${BOLD}BNPRS Session Manager${NC} for Claude Code"
        echo ""
        echo -e "Session ID format:  ${CYAN}E<number>-aid.<NNN>${NC}   e.g. E1026-aid.001"
        echo ""
        echo "Commands:"
        echo "  init                       First-time setup"
        echo "  start  <session-id>        Start or resume a session"
        echo "  sync   <session-id>        Sync GitLab repo only"
        echo "  list                       List all sessions"
        echo "  status <session-id>        Show session details + repo memory"
        echo "  delete <session-id>        Delete local session meta"
        echo "  save-memory <session-id>   Save notes → repo 08-memory/ + push"
        echo ""
        echo "Examples:"
        echo "  ./bnprs-sessions.sh init"
        echo "  ./bnprs-sessions.sh start E1026-aid.001"
        echo "  ./bnprs-sessions.sh save-memory E1026-aid.001"
        echo "  ./bnprs-sessions.sh list"
        echo "  ./bnprs-sessions.sh status E1026-aid.001"
        echo ""
        echo "Env vars:"
        echo "  GITLAB_PAT        required — your GitLab personal access token"
        echo "  GITLAB_HOST       default: gitlab.bnprs.ai"
        echo "  GITLAB_GROUP      default: aim1001"
        echo "  REPOS_DIR         default: ~/aim1001"
        echo ""
        ;;
esac
