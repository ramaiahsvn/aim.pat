#!/bin/bash
# ============================================================
#  create-agent.sh — Scaffold a new AI Agent from the Neuron template
# ============================================================
#  Usage:
#    ./create-agent.sh
#    ./create-agent.sh --name "DocBot" --role "Document Specialist"
#    ./create-agent.sh --name "ResearchAgent" --role "Research Analyst" --output ~/agents
# ============================================================

set -e

# ---- Defaults ---- #
AGENT_NAME=""
AGENT_ROLE=""
OUTPUT_DIR="."
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Parse arguments ---- #
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)    AGENT_NAME="$2"; shift 2 ;;
    --role)    AGENT_ROLE="$2"; shift 2 ;;
    --output)  OUTPUT_DIR="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: ./create-agent.sh [--name <name>] [--role <role>] [--output <dir>]"
      echo ""
      echo "Options:"
      echo "  --name    Agent name (e.g., 'DocBot', 'ResearchAgent')"
      echo "  --role    Agent role (e.g., 'Document Specialist')"
      echo "  --output  Directory to create the agent in (default: current dir)"
      echo ""
      echo "If --name or --role are not provided, you'll be prompted interactively."
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---- Interactive prompts if not provided ---- #
if [ -z "$AGENT_NAME" ]; then
  echo "================================================"
  echo "  Create New Agent (Neuron Architecture)"
  echo "================================================"
  echo ""
  read -p "Agent name (e.g., DocBot): " AGENT_NAME
fi

if [ -z "$AGENT_ROLE" ]; then
  read -p "Agent role (e.g., Document Specialist): " AGENT_ROLE
fi

# Validate
if [ -z "$AGENT_NAME" ]; then
  echo "Error: Agent name is required."
  exit 1
fi

# ---- Derive folder name ---- #
FOLDER_NAME=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
AGENT_DIR="$OUTPUT_DIR/$FOLDER_NAME"

if [ -d "$AGENT_DIR" ]; then
  echo "Error: Directory '$AGENT_DIR' already exists."
  exit 1
fi

echo ""
echo "Creating agent: $AGENT_NAME"
echo "Role: $AGENT_ROLE"
echo "Location: $AGENT_DIR"
echo ""

# ---- Create folder structure ---- #
mkdir -p "$AGENT_DIR"/{01-dendrite/{connectors,inputs,sensors},02-cell-body/{reasoning,models,planning/{todo,status,priorities}},03-nucleus,04-axon/{workflows,pipelines},05-myelin-sheath/{skill-template,skill-docx,skill-web-search},06-node-of-ranvier,07-axon-terminals/{actions,deliverables,notifications},08-memory/{short-term,long-term,learned-preferences}}

# ---- Copy template files ---- #
# Dendrite
cp "$TEMPLATE_DIR/01-dendrite/README.md" "$AGENT_DIR/01-dendrite/"
cp "$TEMPLATE_DIR/01-dendrite/connectors/_template.yaml" "$AGENT_DIR/01-dendrite/connectors/"
cp "$TEMPLATE_DIR/01-dendrite/inputs/schema.yaml" "$AGENT_DIR/01-dendrite/inputs/"
cp "$TEMPLATE_DIR/01-dendrite/sensors/web-search.yaml" "$AGENT_DIR/01-dendrite/sensors/"

# Cell Body
cp "$TEMPLATE_DIR/02-cell-body/README.md" "$AGENT_DIR/02-cell-body/"
cp "$TEMPLATE_DIR/02-cell-body/models/default.yaml" "$AGENT_DIR/02-cell-body/models/"
cp "$TEMPLATE_DIR/02-cell-body/reasoning/strategies.yaml" "$AGENT_DIR/02-cell-body/reasoning/"
cp "$TEMPLATE_DIR/02-cell-body/planning/todo/task-template.yaml" "$AGENT_DIR/02-cell-body/planning/todo/"
cp "$TEMPLATE_DIR/02-cell-body/planning/status/current.yaml" "$AGENT_DIR/02-cell-body/planning/status/"
cp "$TEMPLATE_DIR/02-cell-body/planning/priorities/rules.yaml" "$AGENT_DIR/02-cell-body/planning/priorities/"

# Nucleus (combined CLAUDE.md)
cp "$TEMPLATE_DIR/03-nucleus/README.md" "$AGENT_DIR/03-nucleus/"
cp "$TEMPLATE_DIR/03-nucleus/CLAUDE.md" "$AGENT_DIR/03-nucleus/"

# Axon
cp "$TEMPLATE_DIR/04-axon/README.md" "$AGENT_DIR/04-axon/"
cp "$TEMPLATE_DIR/04-axon/workflows/document-creation.yaml" "$AGENT_DIR/04-axon/workflows/"
cp "$TEMPLATE_DIR/04-axon/pipelines/research-to-report.yaml" "$AGENT_DIR/04-axon/pipelines/"

# Myelin Sheath
cp "$TEMPLATE_DIR/05-myelin-sheath/README.md" "$AGENT_DIR/05-myelin-sheath/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-template/SKILL.md" "$AGENT_DIR/05-myelin-sheath/skill-template/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-docx/SKILL.md" "$AGENT_DIR/05-myelin-sheath/skill-docx/"
cp "$TEMPLATE_DIR/05-myelin-sheath/skill-web-search/SKILL.md" "$AGENT_DIR/05-myelin-sheath/skill-web-search/"

# Node of Ranvier
cp "$TEMPLATE_DIR/06-node-of-ranvier/README.md" "$AGENT_DIR/06-node-of-ranvier/"
cp "$TEMPLATE_DIR/06-node-of-ranvier/checkpoint-template.yaml" "$AGENT_DIR/06-node-of-ranvier/"

# Axon Terminals
cp "$TEMPLATE_DIR/07-axon-terminals/README.md" "$AGENT_DIR/07-axon-terminals/"
cp "$TEMPLATE_DIR/07-axon-terminals/actions/available-actions.yaml" "$AGENT_DIR/07-axon-terminals/actions/"
cp "$TEMPLATE_DIR/07-axon-terminals/notifications/templates.yaml" "$AGENT_DIR/07-axon-terminals/notifications/"

# Memory
cp "$TEMPLATE_DIR/08-memory/README.md" "$AGENT_DIR/08-memory/"
cp "$TEMPLATE_DIR/08-memory/short-term/session.yaml" "$AGENT_DIR/08-memory/short-term/"
cp "$TEMPLATE_DIR/08-memory/long-term/knowledge.yaml" "$AGENT_DIR/08-memory/long-term/"
cp "$TEMPLATE_DIR/08-memory/learned-preferences/user-prefs.yaml" "$AGENT_DIR/08-memory/learned-preferences/"

# Root files
cp "$TEMPLATE_DIR/README.md" "$AGENT_DIR/"
cp "$TEMPLATE_DIR/agent.yaml" "$AGENT_DIR/"

# ---- Replace placeholders ---- #
TODAY=$(date +"%Y-%m-%d")

# agent.yaml
sed -i "s|<Agent Name>|$AGENT_NAME|g" "$AGENT_DIR/agent.yaml"
sed -i "s|<Your Name>|$(whoami)|g" "$AGENT_DIR/agent.yaml"
sed -i "s|<date>|$TODAY|g" "$AGENT_DIR/agent.yaml"
sed -i "s|<What this agent does>|$AGENT_ROLE agent|g" "$AGENT_DIR/agent.yaml"

# nucleus/CLAUDE.md (combined identity + prompt + guardrails)
sed -i "s|<Agent Name>|$AGENT_NAME|g" "$AGENT_DIR/03-nucleus/CLAUDE.md"
sed -i "s|<Primary Role>|$AGENT_ROLE|g" "$AGENT_DIR/03-nucleus/CLAUDE.md"

# ---- Done ---- #
echo "================================================"
echo "  Agent '$AGENT_NAME' created successfully!"
echo "================================================"
echo ""
echo "  Location: $AGENT_DIR"
echo ""
echo "  Next steps:"
echo "  1. Edit 03-nucleus/system-prompt.md  — refine instructions"
echo "  2. Edit 03-nucleus/guardrails.yaml   — set safety rules"
echo "  3. Add connectors in 01-dendrite/    — plug in your tools"
echo "  4. Add skills in 05-myelin-sheath/   — accelerate tasks"
echo "  5. Define workflows in 04-axon/      — orchestrate execution"
echo ""
echo "  Total files: $(find "$AGENT_DIR" -type f | wc -l)"
echo "  Total folders: $(find "$AGENT_DIR" -type d | wc -l)"
echo ""
