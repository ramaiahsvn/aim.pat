#!/bin/bash
# ============================================================
#  create-agent-real.sh — BNPRS Employee Agent Creator
# ============================================================
#  Creates aim1001.aid-XXX agent folder, scaffolds from
#  nagent-template-2, then pushes to gitlab.bnprs.ai.
#
#  Usage: ./create-agent-real.sh
# ============================================================

set -e

# ---- CREDENTIALS ---- #
GITLAB_URL="https://gitlab.bnprs.ai"
GITLAB_PAT="glpat-5EwDo1lFfkOKuEiv9yRN9W86MQp1OjEH.01.0w0wdt517"
GITLAB_GROUP_PATH="aim1001"
GITLAB_GROUP_NAME="AIM Team"

# ---- PATHS ---- #
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/nagent-template-2"
AGENTS_DIR="$SCRIPT_DIR"

# ---- COLORS ---- #
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo ""
echo "============================================="
echo "  BNPRS Employee Agent Creator"
echo "============================================="
echo ""

# ---- PROMPT FOR EMPLOYEE DETAILS ---- #
read -p "Employee Name       : " EMP_NAME
read -p "Employee ID (EID)   : " EMP_EID
read -p "Role / Department   : " EMP_ROLE

if [[ -z "$EMP_NAME" || -z "$EMP_EID" ]]; then
  echo -e "${RED}Error: Employee Name and EID are required.${NC}"
  exit 1
fi

# ---- AUTO-ASSIGN NEXT AID ---- #
LAST=$(ls -d "$AGENTS_DIR"/aim1001.aid-* 2>/dev/null | grep -oE 'aid-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
NEXT=$(( ${LAST:-0} + 1 ))
AID=$(printf "%03d" "$NEXT")
FOLDER_NAME="aim1001.aid-${AID}"
FOLDER_PATH="$AGENTS_DIR/$FOLDER_NAME"

echo ""
echo -e "  AID assigned : ${GREEN}AID-${AID}${NC}"
echo -e "  EID          : ${GREEN}${EMP_EID}${NC}"
echo -e "  Folder       : ${GREEN}${FOLDER_PATH}${NC}"
echo ""
read -p "Confirm? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && echo "Cancelled." && exit 0

# ---- SCAFFOLD FROM TEMPLATE ---- #
echo ""
echo -e "${YELLOW}[1/4] Scaffolding from nagent-template-2...${NC}"

cp -r "$TEMPLATE_DIR" "$FOLDER_PATH"

# Remove template git artifacts if any
rm -f "$FOLDER_PATH/.git"

# Customize agent.yaml
sed -i '' \
  "s|<Agent Name>|${FOLDER_NAME}|g; \
   s|<code>|${AID}|g; \
   s|<group>|na-008-bnprs-team|g; \
   s|<What this agent does>|Employee agent for ${EMP_NAME} (${EMP_EID})|g; \
   s|<Your Name>|${EMP_NAME}|g; \
   s|<date>|$(date +%Y-%m-%d)|g" \
  "$FOLDER_PATH/agent.yaml"

# Customize CLAUDE.md
sed -i '' \
  "s|<agent-name>|${FOLDER_NAME}|g; \
   s|<code>|AID-${AID}|g; \
   s|<group>|na-008-bnprs-team|g; \
   s|<one-line role>|${EMP_ROLE}|g; \
   s|<e.g. professional, concise, friendly>|professional, concise|g; \
   s|<e.g. lead with finding, then detail>|lead with finding, then detail|g; \
   s|<e.g. flag issues before being asked>|flag blockers and delays proactively|g; \
   s|<Primary rule>|Focus on assigned sprint tasks|g; \
   s|<Secondary rule>|Deliver outputs in the agreed naming format|g" \
  "$FOLDER_PATH/CLAUDE.md"

# Customize context.yaml
sed -i '' \
  "s|<Project Name>|${EMP_NAME} — ${EMP_ROLE}|g; \
   s|<What this project is about.*>|Employee agent for ${EMP_NAME} (EID: ${EMP_EID}, AID: AID-${AID})|g" \
  "$FOLDER_PATH/01-dand/context.yaml"

echo -e "  ${GREEN}Done.${NC}"

# ---- GIT INIT ---- #
echo -e "${YELLOW}[2/4] Initialising git repository...${NC}"

cd "$FOLDER_PATH"
git init -b master
git add .
git commit -m "feat: init agent ${FOLDER_NAME} for ${EMP_NAME} (${EMP_EID})"

echo -e "  ${GREEN}Done.${NC}"

# ---- ENSURE GitLab GROUP EXISTS ---- #
echo -e "${YELLOW}[3/4] Checking GitLab group ${GITLAB_GROUP_PATH}...${NC}"

GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  "${GITLAB_URL}/api/v4/groups?search=${GITLAB_GROUP_PATH}" | \
  python3 -c "import sys,json; g=json.load(sys.stdin); print(next((x['id'] for x in g if x['path']=='"${GITLAB_GROUP_PATH}"'), ''))" 2>/dev/null)

if [[ -z "$GROUP_ID" ]]; then
  echo "  Group not found — creating ${GITLAB_GROUP_NAME}..."
  GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" \
    --data "name=${GITLAB_GROUP_NAME}&path=${GITLAB_GROUP_PATH}&visibility=private" \
    "${GITLAB_URL}/api/v4/groups" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  echo -e "  ${GREEN}Group created (ID: ${GROUP_ID}).${NC}"
else
  echo -e "  ${GREEN}Group exists (ID: ${GROUP_ID}).${NC}"
fi

# ---- CREATE GitLab PROJECT AND PUSH ---- #
echo -e "${YELLOW}[4/4] Creating GitLab project and pushing...${NC}"

PROJECT=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  --data "name=${FOLDER_NAME}&path=${FOLDER_NAME}&namespace_id=${GROUP_ID}&visibility=private&default_branch=master&initialize_with_readme=false" \
  "${GITLAB_URL}/api/v4/projects")

PROJECT_ID=$(echo "$PROJECT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
PROJECT_URL=$(echo "$PROJECT" | python3 -c "import sys,json; print(json.load(sys.stdin)['http_url_to_repo'])")

# Inject token into remote URL for push
PUSH_URL="${PROJECT_URL/https:\/\//https://oauth2:${GITLAB_PAT}@}"

git remote add origin "$PUSH_URL"
git push -u origin master

# Set clean remote URL (no token)
git remote set-url origin "$PROJECT_URL"

echo ""
echo "============================================="
echo -e "  ${GREEN}Agent created successfully!${NC}"
echo "---------------------------------------------"
echo "  Folder  : $FOLDER_PATH"
echo "  AID     : AID-${AID}  →  EID: ${EMP_EID}"
echo "  GitLab  : ${GITLAB_URL}/${GITLAB_GROUP_PATH}/${FOLDER_NAME}"
echo "============================================="
echo ""
echo "Next: add this employee to na-008-bnprs-team/README.md"
echo "  | AID-${AID} | ${EMP_EID} | ${EMP_NAME} | ${EMP_ROLE} | active |"
echo ""
