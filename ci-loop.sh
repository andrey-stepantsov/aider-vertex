#!/bin/bash
set -e

TARGET_BRANCH="agent/linux-testing"
WORKFLOW_FILE="check.yml" # <--- Updated to match your file

echo ">>> [Local] pushing current state to $TARGET_BRANCH..."

# 1. Force push to the target branch
git push origin HEAD:refs/heads/$TARGET_BRANCH --force

# 2. Trigger the workflow manually to be sure, targeting the correct branch
echo ">>> [GitHub] Triggering workflow on $TARGET_BRANCH..."
gh workflow run $WORKFLOW_FILE --ref $TARGET_BRANCH

# 3. Wait for the run to register
sleep 5

# 4. Get the Run ID
RUN_ID=$(gh run list --workflow $WORKFLOW_FILE --branch $TARGET_BRANCH --limit 1 --json databaseId --jq '.[0].databaseId')

echo ">>> [GitHub] Watching Run ID: $RUN_ID"

# 5. Watch the build
set +e
gh run watch $RUN_ID --exit-status
EXIT_CODE=$?
set -e

# 6. Fetch logs on failure
if [ $EXIT_CODE -ne 0 ]; then
    echo ">>> [GitHub] Build Failed! Fetching failure logs..."
    echo "==================================================="
    # Fetch logs for the failed steps. Tailing 300 lines usually catches the Nix error.
    gh run view $RUN_ID --log-failed | tail -n 300
    echo "==================================================="
    echo ">>> [Aider] Please fix the errors above."
    exit 1
else
    echo ">>> [GitHub] Build Succeeded!"
    exit 0
fi