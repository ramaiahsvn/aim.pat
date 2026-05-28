#!/bin/bash
# GitHub → GitLab migration script (2026-02-25)
# Migrates all repos prefixed "bpr1010" from GitHub (bnprs org) to GitLab group bpr1010.
# Token: set GITLAB_TOKEN env var (stored in secrets/shell-exports.sh — never hardcode here)

GITLAB_HOST="https://gitlab.bnprs.ai"
GITLAB_TOKEN="${GITLAB_TOKEN}"   # export GITLAB_TOKEN=<glpat-...> before running
GITLAB_GROUP="bpr1010"

# Fetch the GitLab group ID
echo "Fetching GitLab group ID for '$GITLAB_GROUP'..."
GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "$GITLAB_HOST/api/v4/groups/$GITLAB_GROUP" | jq -r '.id')

if [ -z "$GROUP_ID" ] || [ "$GROUP_ID" == "null" ]; then
    echo "ERROR: Could not find GitLab group '$GITLAB_GROUP'. Check the group name and token."
    exit 1
fi

echo "Group ID: $GROUP_ID"

repos=$(gh repo list bnprs --limit 1000 --json name,sshUrl \
    -q '.[] | select(.name | startswith("bpr1010")) | .sshUrl')

for repo in $repos; do
    echo ""
    echo "Migrating $repo..."

    repo_file=$(basename "$repo")           # e.g. bpr1010.bpass.engine.git
    repo_name="${repo_file%.git}"           # e.g. bpr1010.bpass.engine

    # Create repo in GitLab group
    echo "  Creating GitLab repo '$repo_name'..."
    CREATE_RESPONSE=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"name\": \"$repo_name\", \"namespace_id\": $GROUP_ID, \"visibility\": \"private\"}" \
        "$GITLAB_HOST/api/v4/projects")

    GITLAB_SSH_URL=$(echo "$CREATE_RESPONSE" | jq -r '.ssh_url_to_repo')

    if [ -z "$GITLAB_SSH_URL" ] || [ "$GITLAB_SSH_URL" == "null" ]; then
        # Repo may already exist — try to fetch its SSH URL
        EXISTING=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            "$GITLAB_HOST/api/v4/projects/$GITLAB_GROUP%2F$(echo $repo_name | sed 's/\./%2E/g')")
        GITLAB_SSH_URL=$(echo "$EXISTING" | jq -r '.ssh_url_to_repo')

        if [ -z "$GITLAB_SSH_URL" ] || [ "$GITLAB_SSH_URL" == "null" ]; then
            echo "  ERROR: Failed to create or find repo '$repo_name'. Skipping."
            echo "  Response: $CREATE_RESPONSE"
            continue
        fi
        echo "  Repo already exists: $GITLAB_SSH_URL"
    fi

    echo "  Created: $GITLAB_SSH_URL"

    # Mirror clone from GitHub
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone --mirror "$repo"
    cd "$repo_file"

    # Push mirror to GitLab
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git push --mirror "$GITLAB_SSH_URL"

    cd ..
    rm -rf "$repo_file"

    echo "  Done: $repo_name"
done

echo ""
echo "Migration complete."
