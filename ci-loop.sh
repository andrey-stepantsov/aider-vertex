#!/bin/bash
set -e

# 0. Auto-commit dirty changes so they aren't left behind
if [ -n "$(git status --porcelain)" ]; then
  echo ">>> [Local] Uncommitted changes detected. Committing as 'wip: auto-commit for CI'..."
  git add .
  git commit -m "wip: auto-commit for CI"
fi

# 1. Dynamically detect the current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TARGET_BRANCH="$CURRENT_BRANCH"
WORKFLOW_FILE="check.yml"

# Safety: Prevent accidental force pushes to protected branches
if [[ "$TARGET_BRANCH" == "main" || "$TARGET_BRANCH" == "master" ]]; then
    echo "❌ Error: This script uses --force push. Do not run it on '$TARGET_BRANCH'."
    exit 1
fi

echo ">>> [Local] Detected branch: $TARGET_BRANCH"
echo ">>> [Local] Pushing current state to origin/$TARGET_BRANCH..."

# 2. Force push to the detected branch
git push origin HEAD:refs/heads/$TARGET_BRANCH --force

# 3. Trigger the workflow
echo ">>> [GitHub] Triggering workflow on $TARGET_BRANCH..."
gh workflow run $WORKFLOW_FILE --ref $TARGET_BRANCH

# 4. Wait for the run to register
sleep 5

# 5. Get the Run ID
RUN_ID=$(gh run list --workflow $WORKFLOW_FILE --branch $TARGET_BRANCH --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    echo "❌ Error: Could not find a running workflow on $TARGET_BRANCH."
    exit 1
fi

echo ">>> [GitHub] Watching Run ID: $RUN_ID"

# 6. Watch the build
set +e
gh run watch $RUN_ID --exit-status
EXIT_CODE=$?
set -e

# 7. Fetch logs on failure
if [ $EXIT_CODE -ne 0 ]; then
    echo ">>> [GitHub] Build Failed! Fetching failure logs..."
    echo "==================================================="
    # Fetch logs for the failed steps
    gh run view $RUN_ID --log-failed | tail -n 300
    echo "==================================================="
    echo ">>> [Aider] Please fix the errors above."
    exit 1
else
    echo ">>> [GitHub] Build Succeeded!"
    exit 0
fi
