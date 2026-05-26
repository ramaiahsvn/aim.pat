#!/usr/bin/env bash
# ============================================================
#  create-agent.sh — Scaffold a new nagent in the right group
# ============================================================
#  Agent codes: 01–FF per group (255 max). Inspired by ISO 8583
#  DE numbering — docs may refer to them as DE01, DE02, etc.
#  Codes are PERMANENT — once assigned, never reused.
#
#  Usage:
#    ./create-agent.sh
#    ./create-agent.sh --group na-001 --name "Daily Briefing" --role "Briefing Agent"
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAGENTS_DIR="$ROOT_DIR/nagents"
TEMPLATE_DIR="$ROOT_DIR/nagent-template"

# ---- Colors ---- #
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

# ---- Parse args ---- #
ARG_GROUP=""
ARG_NAME=""
ARG_ROLE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --group)  ARG_GROUP="$2"; shift 2 ;;
    --name)   ARG_NAME="$2";  shift 2 ;;
    --role)   ARG_ROLE="$2";  shift 2 ;;
    --help|-h)
      echo "Usage: ./create-agent.sh [--group <na-00N>] [--name <name>] [--role <role>]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ============================================================
#  STEP 1 — SELECT GROUP
# ============================================================

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         aim.pat — Create New nagent                  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# Discover groups from nagents/ folder
mapfile -t GROUP_DIRS < <(find "$NAGENTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#GROUP_DIRS[@]} -eq 0 ]]; then
  echo -e "${RED}No groups found in nagents/. Create a group folder first.${RESET}"
  exit 1
fi

if [[ -z "$ARG_GROUP" ]]; then
  echo -e "${CYAN}${BOLD}Select a nagent group:${RESET}"
  echo ""

  declare -A GROUP_MAP
  IDX=1
  for gdir in "${GROUP_DIRS[@]}"; do
    gname=$(basename "$gdir")
    registry="$gdir/registry.yaml"
    count=0
    if [[ -f "$registry" ]]; then
      count=$(grep -c "^  - code:" "$registry" 2>/dev/null || true)
    fi
    desc=""
    if [[ -f "$registry" ]]; then
      desc=$(grep "description:" "$registry" | head -1 | sed 's/.*description: *"//' | sed 's/".*//')
    fi
    printf "  ${BOLD}[%d]${RESET}  %-35s ${DIM}%d agents | %s${RESET}\n" \
           "$IDX" "$gname" "$count" "$desc"
    GROUP_MAP[$IDX]="$gdir"
    ((IDX++))
  done

  echo ""
  read -rp "  Group number: " CHOICE

  if [[ -z "${GROUP_MAP[$CHOICE]+_}" ]]; then
    echo -e "${RED}Invalid choice.${RESET}"
    exit 1
  fi
  SELECTED_GROUP_DIR="${GROUP_MAP[$CHOICE]}"
else
  SELECTED_GROUP_DIR=""
  for gdir in "${GROUP_DIRS[@]}"; do
    if [[ "$(basename "$gdir")" == "$ARG_GROUP"* ]]; then
      SELECTED_GROUP_DIR="$gdir"
      break
    fi
  done
  if [[ -z "$SELECTED_GROUP_DIR" ]]; then
    echo -e "${RED}Group '$ARG_GROUP' not found.${RESET}"
    exit 1
  fi
fi

GROUP_NAME=$(basename "$SELECTED_GROUP_DIR")
GROUP_REGISTRY="$SELECTED_GROUP_DIR/registry.yaml"

echo ""
echo -e "  ${GREEN}Group:${RESET} $GROUP_NAME"

# ============================================================
#  STEP 2 — ASSIGN NEXT CODE
# ============================================================

# Collect already-used codes from registry
mapfile -t USED_CODES < <(grep "^  - code:" "$GROUP_REGISTRY" 2>/dev/null | sed 's/.*"\([0-9A-Fa-f]*\)".*/\1/' | tr '[:lower:]' '[:upper:]' || true)

# Find next available code 01–FF
NEXT_CODE=""
for i in $(seq 1 255); do
  HEX=$(printf '%02X' "$i")
  TAKEN=false
  for used in "${USED_CODES[@]}"; do
    if [[ "$used" == "$HEX" ]]; then
      TAKEN=true
      break
    fi
  done
  if [[ "$TAKEN" == false ]]; then
    NEXT_CODE="$HEX"
    break
  fi
done

if [[ -z "$NEXT_CODE" ]]; then
  echo -e "${RED}Group '$GROUP_NAME' is full (255/255 agents).${RESET}"
  exit 1
fi

USED_COUNT=${#USED_CODES[@]}
echo -e "  ${GREEN}Next code:${RESET} $NEXT_CODE  ${DIM}(${USED_COUNT}/255 used | ref: DE$NEXT_CODE)${RESET}"

# ============================================================
#  STEP 3 — AGENT NAME & ROLE
# ============================================================

echo ""
if [[ -z "$ARG_NAME" ]]; then
  read -rp "  Agent name (e.g. Daily Briefing): " AGENT_NAME
else
  AGENT_NAME="$ARG_NAME"
  echo -e "  ${GREEN}Agent name:${RESET} $AGENT_NAME"
fi

if [[ -z "$AGENT_NAME" ]]; then
  echo -e "${RED}Agent name is required.${RESET}"
  exit 1
fi

if [[ -z "$ARG_ROLE" ]]; then
  read -rp "  Agent role (e.g. Briefing Specialist): " AGENT_ROLE
else
  AGENT_ROLE="$ARG_ROLE"
  echo -e "  ${GREEN}Agent role:${RESET} $AGENT_ROLE"
fi

# ============================================================
#  STEP 4 — CONFIRM
# ============================================================

SLUG=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
AGENT_FOLDER="${NEXT_CODE}-${SLUG}"
AGENT_DIR="$SELECTED_GROUP_DIR/$AGENT_FOLDER"

echo ""
echo -e "${YELLOW}${BOLD}  Summary${RESET}"
echo -e "  Group  : $GROUP_NAME"
echo -e "  Code   : $NEXT_CODE"
echo -e "  Name   : $AGENT_NAME"
echo -e "  Role   : $AGENT_ROLE"
echo -e "  Folder : nagents/$GROUP_NAME/$AGENT_FOLDER/"
echo ""
read -rp "  Proceed? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ "$CONFIRM" != [Yy] ]]; then
  echo "Aborted."
  exit 0
fi

# ============================================================
#  STEP 5 — SCAFFOLD AGENT FROM TEMPLATE
# ============================================================

echo ""
echo -e "  Creating folder structure..."

mkdir -p "$AGENT_DIR"/{01-dendrite/{connectors,inputs,sensors,secrets},02-cell-body/{reasoning,models,planning/{todo,status,priorities}},03-nucleus,04-axon/{workflows,pipelines},05-myelin-sheath/{skill-template,skill-docx,skill-web-search},06-node-of-ranvier,07-axon-terminals/{actions,deliverables,notifications},08-memory/{short-term,long-term,learned-preferences}}

# Copy template files
cp "$TEMPLATE_DIR/01-dendrite/README.md"                        "$AGENT_DIR/01-dendrite/"
cp "$TEMPLATE_DIR/01-dendrite/connectors/_template.yaml"        "$AGENT_DIR/01-dendrite/connectors/"
cp "$TEMPLATE_DIR/01-dendrite/inputs/schema.yaml"               "$AGENT_DIR/01-dendrite/inputs/"
cp "$TEMPLATE_DIR/01-dendrite/sensors/web-search.yaml"          "$AGENT_DIR/01-dendrite/sensors/"
cp "$TEMPLATE_DIR/01-dendrite/secrets/.gitignore"               "$AGENT_DIR/01-dendrite/secrets/"
cp "$TEMPLATE_DIR/01-dendrite/secrets/secrets.example.yaml"     "$AGENT_DIR/01-dendrite/secrets/"

cp "$TEMPLATE_DIR/02-cell-body/README.md"                       "$AGENT_DIR/02-cell-body/"
cp "$TEMPLATE_DIR/02-cell-body/models/default.yaml"             "$AGENT_DIR/02-cell-body/models/"
cp "$TEMPLATE_DIR/02-cell-body/reasoning/strategies.yaml"       "$AGENT_DIR/02-cell-body/reasoning/"
cp "$TEMPLATE_DIR/02-cell-body/planning/todo/task-template.yaml" "$AGENT_DIR/02-cell-body/planning/todo/"
cp "$TEMPLATE_DIR/02-cell-body/planning/status/current.yaml"    "$AGENT_DIR/02-cell-body/planning/status/"
cp "$TEMPLATE_DIR/02-cell-body/planning/priorities/rules.yaml"  "$AGENT_DIR/02-cell-body/planning/priorities/"

cp "$TEMPLATE_DIR/03-nucleus/README.md"                         "$AGENT_DIR/03-nucleus/"
cp "$TEMPLATE_DIR/03-nucleus/CLAUDE.md"                         "$AGENT_DIR/03-nucleus/"

cp "$TEMPLATE_DIR/04-axon/README.md"                            "$AGENT_DIR/04-axon/"
cp "$TEMPLATE_DIR/04-axon/workflows/document-creation.yaml"     "$AGENT_DIR/04-axon/workflows/"
cp "$TEMPLATE_DIR/04-axon/pipelines/research-to-report.yaml"    "$AGENT_DIR/04-axon/pipelines/"

cp "$TEMPLATE_DIR/05-myelin-sheath/README.md"                   "$AGENT_DIR/05-myelin-sheath/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-template/SKILL.md"     "$AGENT_DIR/05-myelin-sheath/skill-template/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-docx/SKILL.md"         "$AGENT_DIR/05-myelin-sheath/skill-docx/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-web-search/SKILL.md"   "$AGENT_DIR/05-myelin-sheath/skill-web-search/"

cp "$TEMPLATE_DIR/06-node-of-ranvier/README.md"                 "$AGENT_DIR/06-node-of-ranvier/"
cp "$TEMPLATE_DIR/06-node-of-ranvier/checkpoint-template.yaml"  "$AGENT_DIR/06-node-of-ranvier/"

cp "$TEMPLATE_DIR/07-axon-terminals/README.md"                  "$AGENT_DIR/07-axon-terminals/"
cp "$TEMPLATE_DIR/07-axon-terminals/actions/available-actions.yaml" "$AGENT_DIR/07-axon-terminals/actions/"
cp "$TEMPLATE_DIR/07-axon-terminals/notifications/templates.yaml"   "$AGENT_DIR/07-axon-terminals/notifications/"

cp "$TEMPLATE_DIR/08-memory/README.md"                          "$AGENT_DIR/08-memory/"
cp "$TEMPLATE_DIR/08-memory/short-term/session.yaml"            "$AGENT_DIR/08-memory/short-term/"
cp "$TEMPLATE_DIR/08-memory/long-term/knowledge.yaml"           "$AGENT_DIR/08-memory/long-term/"
cp "$TEMPLATE_DIR/08-memory/learned-preferences/user-prefs.yaml" "$AGENT_DIR/08-memory/learned-preferences/"

cp "$TEMPLATE_DIR/README.md"  "$AGENT_DIR/"
cp "$TEMPLATE_DIR/agent.yaml" "$AGENT_DIR/"

# Substitute placeholders
TODAY=$(date +"%Y-%m-%d")
CREATOR=$(whoami)

sed -i "s|<Agent Name>|$AGENT_NAME|g"           "$AGENT_DIR/agent.yaml"
sed -i "s|<code>|$NEXT_CODE|g"                  "$AGENT_DIR/agent.yaml"
sed -i "s|<group>|$GROUP_NAME|g"                "$AGENT_DIR/agent.yaml"
sed -i "s|<Your Name>|$CREATOR|g"               "$AGENT_DIR/agent.yaml"
sed -i "s|<date>|$TODAY|g"                      "$AGENT_DIR/agent.yaml"
sed -i "s|<What this agent does>|${AGENT_ROLE//&/\\&}|g" "$AGENT_DIR/agent.yaml"

sed -i "s|<Agent Name>|$AGENT_NAME|g"                        "$AGENT_DIR/03-nucleus/CLAUDE.md"
sed -i "s|<code>|$NEXT_CODE|g"                               "$AGENT_DIR/03-nucleus/CLAUDE.md"
sed -i "s|<group>|$GROUP_NAME|g"                             "$AGENT_DIR/03-nucleus/CLAUDE.md"
sed -i "s|<Primary Role>|${AGENT_ROLE//&/\\&}|g"             "$AGENT_DIR/03-nucleus/CLAUDE.md"

# ============================================================
#  STEP 6 — REGISTER AGENT (append to registry.yaml)
# ============================================================

echo -e "  Registering $NEXT_CODE in registry..."

# Append to registry list — replace "registry: []" or append to existing list
if grep -q "^registry: \[\]" "$GROUP_REGISTRY"; then
  sed -i "s|^registry: \[\]|registry:\n  - code: \"$NEXT_CODE\"\n    name: \"$SLUG\"\n    label: \"$AGENT_NAME\"\n    role: \"$AGENT_ROLE\"\n    path: \"$AGENT_FOLDER\"\n    status: \"active\"\n    created_at: \"$TODAY\"\n    created_by: \"$CREATOR\"|" "$GROUP_REGISTRY"
else
  # Append before the pruning comment block at end of file
  cat >> "$GROUP_REGISTRY" << ENTRY

  - code: "$NEXT_CODE"
    name: "$SLUG"
    label: "$AGENT_NAME"
    role: "$AGENT_ROLE"
    path: "$AGENT_FOLDER"
    status: "active"
    created_at: "$TODAY"
    created_by: "$CREATOR"
ENTRY
fi

# ============================================================
#  DONE
# ============================================================

FILE_COUNT=$(find "$AGENT_DIR" -type f | wc -l | tr -d ' ')
DIR_COUNT=$(find  "$AGENT_DIR" -type d | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║   Agent '$AGENT_NAME' created!${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Code    :${RESET} $NEXT_CODE (permanent, never reused)"
echo -e "  ${BOLD}Location:${RESET} nagents/$GROUP_NAME/$AGENT_FOLDER/"
echo -e "  ${BOLD}Files   :${RESET} $FILE_COUNT files · $DIR_COUNT folders"
echo ""
echo -e "  ${CYAN}Next steps:${RESET}"
echo -e "  1. Edit  03-nucleus/CLAUDE.md           — define identity & guardrails"
echo -e "  2. Edit  01-dendrite/secrets/secrets.yaml — add connector credentials"
echo -e "  3. Add   05-myelin-sheath/<skill>/       — load domain skills"
echo -e "  4. Write 04-axon/workflows/              — define execution pipelines"
echo -e "  5. Open  agent.yaml                      — review and finalise manifest"
echo ""
