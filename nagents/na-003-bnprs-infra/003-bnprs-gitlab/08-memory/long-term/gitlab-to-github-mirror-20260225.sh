#!/bin/bash

###############################################################################
# GitLab → GitHub Mirror Script (2026-02-25)
# Mirrors ALL repos from ALL groups in GitLab to corresponding GitHub orgs/repos
# Token: set GITLAB_TOKEN env var (stored in secrets/shell-exports.sh — never hardcode here)
###############################################################################

GITLAB_HOST="https://gitlab.bnprs.ai"
GITLAB_TOKEN="${GITLAB_TOKEN}"   # export GITLAB_TOKEN=<glpat-...> before running
GITHUB_ORG="bnprs"  # GitHub organization to push repos into

# --- Configuration ---
PER_PAGE=100
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "============================================="
echo " GitLab → GitHub Migration"
echo "============================================="
echo ""

# --- Step 1: Fetch all top-level groups ---
echo "Fetching all GitLab groups..."
page=1
ALL_GROUPS="[]"
while true; do
    response=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$GITLAB_HOST/api/v4/groups?per_page=$PER_PAGE&page=$page&top_level_only=true")
    count=$(echo "$response" | jq 'length')
    if [ "$count" -eq 0 ] || [ "$count" == "null" ]; then
        break
    fi
    ALL_GROUPS=$(echo "$ALL_GROUPS $response" | jq -s 'add')
    ((page++))
done

GROUP_COUNT=$(echo "$ALL_GROUPS" | jq 'length')
echo "Found $GROUP_COUNT top-level group(s)."
echo ""

# --- Step 2: Iterate over each group ---
echo "$ALL_GROUPS" | jq -r '.[] | "\(.id) \(.full_path)"' | while read -r GROUP_ID GROUP_PATH; do
    echo "============================================="
    echo "Processing group: $GROUP_PATH (ID: $GROUP_ID)"
    echo "============================================="

    # --- Step 3: Fetch all projects in this group (including subgroups) ---
    page=1
    ALL_PROJECTS="[]"
    while true; do
        response=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            "$GITLAB_HOST/api/v4/groups/$GROUP_ID/projects?per_page=$PER_PAGE&page=$page&include_subgroups=true&archived=false")
        count=$(echo "$response" | jq 'length')
        if [ "$count" -eq 0 ] || [ "$count" == "null" ]; then
            break
        fi
        ALL_PROJECTS=$(echo "$ALL_PROJECTS $response" | jq -s 'add')
        ((page++))
    done

    PROJECT_COUNT=$(echo "$ALL_PROJECTS" | jq 'length')
    echo "Found $PROJECT_COUNT project(s) in group '$GROUP_PATH'."
    echo ""

    # --- Step 4: Mirror each project to GitHub ---
    echo "$ALL_PROJECTS" | jq -r '.[] | "\(.path_with_namespace) \(.ssh_url_to_repo)"' | while read -r PROJECT_PATH SSH_URL; do
        REPO_NAME=$(echo "$PROJECT_PATH" | tr '/' '.')

        echo "  -----------------------------------------------"
        echo "  Migrating: $PROJECT_PATH"
        echo "  GitLab SSH: $SSH_URL"
        echo "  GitHub repo: $GITHUB_ORG/$REPO_NAME"

        # --- Create GitHub repo if it doesn't exist ---
        echo "  Checking/creating GitHub repo '$REPO_NAME'..."
        gh repo view "$GITHUB_ORG/$REPO_NAME" --json name > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "  Creating GitHub repo..."
            gh repo create "$GITHUB_ORG/$REPO_NAME" --private --confirm 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "  ERROR: Failed to create GitHub repo '$GITHUB_ORG/$REPO_NAME'. Skipping."
                continue
            fi
            echo "  Created."
        else
            echo "  Repo already exists on GitHub."
        fi

        # --- Mirror clone from GitLab ---
        CLONE_DIR="$WORK_DIR/${REPO_NAME}.git"
        echo "  Cloning (mirror) from GitLab..."
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
            git clone --mirror "$SSH_URL" "$CLONE_DIR"
        if [ $? -ne 0 ]; then
            echo "  ERROR: Failed to clone '$SSH_URL'. Skipping."
            rm -rf "$CLONE_DIR"
            continue
        fi

        # --- Push mirror to GitHub ---
        GITHUB_SSH_URL="git@github.com:${GITHUB_ORG}/${REPO_NAME}.git"
        echo "  Pushing (mirror) to GitHub..."
        cd "$CLONE_DIR"
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
            git push --force "$GITHUB_SSH_URL" '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*'
        if [ $? -ne 0 ]; then
            echo "  ERROR: Failed to push to GitHub. Skipping."
        else
            echo "  Done: $REPO_NAME ✓"
        fi
        cd "$WORK_DIR"
        rm -rf "$CLONE_DIR"

    done

    echo ""
done

echo "============================================="
echo " Migration complete."
echo "============================================="
