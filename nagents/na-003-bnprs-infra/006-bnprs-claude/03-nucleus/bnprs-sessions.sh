#!/bin/bash
# ============================================================
#  BNPRS Session Manager for Claude Code CLI
#  Fixed session IDs with persistent memory
# ============================================================
#
#  Usage:
#    ./bnprs-sessions.sh start E1026        # Start or resume session E1026
#    ./bnprs-sessions.sh start E1012        # Start or resume session E1012
#    ./bnprs-sessions.sh list               # List all active sessions
#    ./bnprs-sessions.sh status E1026       # Check session status
#    ./bnprs-sessions.sh delete E1026       # Delete a session
#    ./bnprs-sessions.sh init               # First-time setup
#
# ============================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────
SESSIONS_DIR="$HOME/.claude/bnprs-sessions"
MEMORY_DIR="$HOME/.claude/bnprs-memory"
PROJECT_ROOT="${BNPRS_PROJECT_ROOT:-$(pwd)}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────
log()   { echo -e "${GREEN}[bnprs]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bnprs]${NC} $*"; }
err()   { echo -e "${RED}[bnprs]${NC} $*" >&2; }

ensure_dirs() {
    mkdir -p "$SESSIONS_DIR" "$MEMORY_DIR"
}

session_memory_file() {
    echo "$MEMORY_DIR/${1}.md"
}

session_meta_file() {
    echo "$SESSIONS_DIR/${1}.meta"
}

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || uuidgen 2>/dev/null \
        || echo "$(od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-4"substr($5,2)"-"substr($6,1,1)substr($6,2)"-"$7$8$9}')"
}

# ── Commands ────────────────────────────────────────────────

cmd_init() {
    ensure_dirs
    log "Initialized BNPRS session directories"
    log "  Sessions: $SESSIONS_DIR"
    log "  Memory:   $MEMORY_DIR"
    echo ""

    # Create a project-level CLAUDE.md if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        cat > "$PROJECT_ROOT/CLAUDE.md" << 'CLAUDEMD'
# BNPRS Project

## Session System
This project uses fixed session IDs (E1026, E1012, etc.).
When resuming a session, always read the session memory file first:
- Check `~/.claude/bnprs-memory/<session-id>.md` for prior context
- Continue from where the last session left off
- Before ending, update the session memory file with current progress

## Session Memory Protocol
At the START of each session:
1. Read your session memory file
2. Summarize where we left off
3. Continue from that point

At the END of each session (or when asked to save):
1. Write a summary of what was accomplished
2. Note any pending tasks or decisions
3. Save current file/architecture state
CLAUDEMD
        log "Created CLAUDE.md with session protocol"
    else
        warn "CLAUDE.md already exists — skipping"
    fi

    echo ""
    log "${BOLD}Setup complete!${NC} Usage:"
    echo "  ./bnprs-sessions.sh start E1026"
    echo "  ./bnprs-sessions.sh start E1012"
}

cmd_start() {
    local sid="${1:?Session ID required (e.g., E1026)}"
    ensure_dirs

    local mem_file
    mem_file=$(session_memory_file "$sid")
    local meta_file
    meta_file=$(session_meta_file "$sid")

    # Check if this is a new or existing session
    if [[ -f "$meta_file" ]]; then
        # ── Resume existing session ─────────────────────────
        local claude_uuid
        claude_uuid=$(grep "^claude_uuid=" "$meta_file" 2>/dev/null | cut -d= -f2)
        local last_used
        last_used=$(grep "^last_used=" "$meta_file" 2>/dev/null | cut -d= -f2-)

        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Resuming Session: ${sid}${NC}"
        echo -e "${CYAN}║${NC}  Last active: ${last_used:-unknown}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""

        # Update timestamp
        sed -i "s/^last_used=.*/last_used=$(date '+%Y-%m-%d %H:%M:%S')/" "$meta_file"
        local resume_count
        resume_count=$(grep "^resume_count=" "$meta_file" | cut -d= -f2)
        resume_count=$((resume_count + 1))
        sed -i "s/^resume_count=.*/resume_count=$resume_count/" "$meta_file"

        # Build the resume prompt with memory injection
        local resume_prompt=""
        if [[ -f "$mem_file" ]] && [[ -s "$mem_file" ]]; then
            resume_prompt="You are resuming session ${sid} (resume #${resume_count}). Read the session memory below and continue from where we left off.

--- SESSION MEMORY (${sid}) ---
$(cat "$mem_file")
--- END SESSION MEMORY ---

Acknowledge what you remember and ask what I'd like to work on next."
        else
            resume_prompt="Starting session ${sid}. No prior memory found. What would you like to work on?"
        fi

        # Try to resume using the stored Claude UUID
        if [[ -n "$claude_uuid" ]]; then
            log "Attempting to resume Claude session: $claude_uuid"
            $CLAUDE_CMD --resume "$claude_uuid" 2>/dev/null \
                || {
                    warn "Previous Claude session expired. Starting fresh with memory..."
                    local new_uuid
                    new_uuid=$(generate_uuid)
                    sed -i "s/^claude_uuid=.*/claude_uuid=$new_uuid/" "$meta_file"
                    $CLAUDE_CMD --session-id "$new_uuid" --name "bnprs-${sid}" --append-system-prompt "$resume_prompt"
                }
        else
            local new_uuid
            new_uuid=$(generate_uuid)
            sed -i "s/^claude_uuid=.*/claude_uuid=$new_uuid/" "$meta_file"
            $CLAUDE_CMD --session-id "$new_uuid" --name "bnprs-${sid}" --append-system-prompt "$resume_prompt"
        fi

    else
        # ── New session ─────────────────────────────────────
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}New Session: ${sid}${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""

        # Generate a UUID for Claude
        local claude_uuid
        claude_uuid=$(generate_uuid)

        # Create meta file
        cat > "$meta_file" << EOF
session_id=${sid}
claude_uuid=${claude_uuid}
created=$(date '+%Y-%m-%d %H:%M:%S')
last_used=$(date '+%Y-%m-%d %H:%M:%S')
resume_count=0
project_root=${PROJECT_ROOT}
EOF

        # Create initial memory file
        cat > "$mem_file" << EOF
# Session ${sid} Memory

## Created: $(date '+%Y-%m-%d %H:%M:%S')
## Status: New session

### Context
- Project: $(basename "$PROJECT_ROOT")
- Working directory: ${PROJECT_ROOT}

### Progress
_No progress recorded yet._

### Pending Tasks
_None yet._
EOF

        log "Created session files"
        log "  Meta:   $meta_file"
        log "  Memory: $mem_file"
        log "  UUID:   $claude_uuid"
        echo ""

        # Launch Claude with the UUID and friendly name
        $CLAUDE_CMD --session-id "$claude_uuid" --name "bnprs-${sid}"
    fi

    # ── Post-session: prompt to save memory ─────────────────
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Session ${sid} ended.${NC}"
    echo -e "Memory file: ${CYAN}${mem_file}${NC}"
    echo ""
    read -rp "Save session notes? (y/n): " save_notes
    if [[ "$save_notes" == "y" ]]; then
        echo ""
        echo "Enter session notes (Ctrl+D when done):"
        echo "---"
        local notes
        notes=$(cat)
        echo "" >> "$mem_file"
        echo "### Update: $(date '+%Y-%m-%d %H:%M:%S')" >> "$mem_file"
        echo "$notes" >> "$mem_file"
        log "Memory updated for ${sid}"
    fi
}

cmd_list() {
    ensure_dirs
    echo ""
    echo -e "${BOLD}BNPRS Sessions${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  ${BOLD}%-10s %-22s %-22s %s${NC}\n" "ID" "Created" "Last Used" "Resumes"
    echo -e "  ─────────────────────────────────────────────────────────"

    local found=0
    for meta in "$SESSIONS_DIR"/*.meta; do
        [[ -f "$meta" ]] || continue
        found=1
        local sid created last_used resume_count
        sid=$(grep "^session_id=" "$meta" | cut -d= -f2)
        created=$(grep "^created=" "$meta" | cut -d= -f2-)
        last_used=$(grep "^last_used=" "$meta" | cut -d= -f2-)
        resume_count=$(grep "^resume_count=" "$meta" | cut -d= -f2)
        printf "  ${GREEN}%-10s${NC} %-22s %-22s %s\n" "$sid" "$created" "$last_used" "$resume_count"
    done

    if [[ $found -eq 0 ]]; then
        echo "  No sessions found. Run: ./bnprs-sessions.sh start E1026"
    fi
    echo ""
}

cmd_status() {
    local sid="${1:?Session ID required}"
    local meta_file
    meta_file=$(session_meta_file "$sid")
    local mem_file
    mem_file=$(session_memory_file "$sid")

    if [[ ! -f "$meta_file" ]]; then
        err "Session '$sid' not found"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}Session: ${sid}${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$meta_file" | sed 's/^/  /'
    echo ""

    if [[ -f "$mem_file" ]]; then
        echo -e "${BOLD}Memory:${NC}"
        echo -e "───────────────────────────────────"
        cat "$mem_file" | sed 's/^/  /'
    fi
    echo ""
}

cmd_delete() {
    local sid="${1:?Session ID required}"
    local meta_file
    meta_file=$(session_meta_file "$sid")
    local mem_file
    mem_file=$(session_memory_file "$sid")

    if [[ ! -f "$meta_file" ]]; then
        err "Session '$sid' not found"
        exit 1
    fi

    read -rp "Delete session $sid and its memory? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm -f "$meta_file" "$mem_file"
        log "Deleted session $sid"
    fi
}

cmd_save_memory() {
    local sid="${1:?Session ID required}"
    local mem_file
    mem_file=$(session_memory_file "$sid")

    echo "Enter memory content (Ctrl+D when done):"
    local content
    content=$(cat)
    echo "" >> "$mem_file"
    echo "### Update: $(date '+%Y-%m-%d %H:%M:%S')" >> "$mem_file"
    echo "$content" >> "$mem_file"
    log "Memory saved for $sid"
}

# ── Main ────────────────────────────────────────────────────

case "${1:-help}" in
    init)         cmd_init ;;
    start|s)      cmd_start "${2:-}" ;;
    list|ls)      cmd_list ;;
    status|st)    cmd_status "${2:-}" ;;
    delete|rm)    cmd_delete "${2:-}" ;;
    save-memory)  cmd_save_memory "${2:-}" ;;
    help|*)
        echo ""
        echo -e "${BOLD}BNPRS Session Manager${NC} for Claude Code"
        echo ""
        echo "Commands:"
        echo "  init              First-time setup"
        echo "  start <id>        Start or resume a session (e.g., E1026)"
        echo "  list              List all sessions"
        echo "  status <id>       Show session details + memory"
        echo "  delete <id>       Delete a session"
        echo "  save-memory <id>  Append notes to session memory"
        echo ""
        echo "Examples:"
        echo "  ./bnprs-sessions.sh init"
        echo "  ./bnprs-sessions.sh start E1026"
        echo "  ./bnprs-sessions.sh start E1012"
        echo "  ./bnprs-sessions.sh list"
        echo ""
        ;;
esac
