#!/bin/bash
set -e

# Setup Mock Environment
TEST_DIR=$(mktemp -d)
# Resolve canonical path for the root immediately to avoid /var vs /private/var mismatch
REAL_TEST_DIR=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$TEST_DIR")

REPO_ROOT="$REAL_TEST_DIR/repo"
EXTERNAL_ROOT="$REAL_TEST_DIR/external_sdk"
BIN_WEAVE="$(pwd)/bin/weave-view"

# Ensure we use the local bin/weave-headers if it exists
export PATH="$(pwd)/bin:$PATH"

echo "🧪 Testing Header Weaving & External Reporting..."
echo "   Mock Repo: $REPO_ROOT"

# 1. Create Structure
mkdir -p "$REPO_ROOT/src"
mkdir -p "$REPO_ROOT/libs/hidden"
mkdir -p "$EXTERNAL_ROOT/include"

# Create dummy files
touch "$REPO_ROOT/src/main.c"
touch "$REPO_ROOT/libs/hidden/secret.h"
touch "$EXTERNAL_ROOT/include/sdk.h"

# 2. Create compile_commands.json
cat <<JSON > "$REPO_ROOT/compile_commands.json"
[
  {
    "directory": "$REPO_ROOT/src",
    "command": "gcc -c main.c -I../libs/hidden -I$EXTERNAL_ROOT/include",
    "file": "$REPO_ROOT/src/main.c"
  }
]
JSON

# 3. Run weave-view (Only viewing 'src')
cd "$REPO_ROOT"
"$BIN_WEAVE" test_view src > weave.log 2>&1 || true

# 4. Verification

# A. Check Internal Weaving
EXPECTED_LINK="view-test_view/_sys/includes/libs_hidden"
if [ -L "$EXPECTED_LINK" ]; then
    echo "✅ [Internal] Hidden header directory was correctly woven."
else
    echo "❌ [Internal] Failed to weave internal header."
    echo "   Expected symlink at: $EXPECTED_LINK"
    echo "--- WEAVE LOG ---"
    cat weave.log
    echo "-----------------"
    ls -R view-test_view/_sys
    exit 1
fi

# B. Check External Reporting
# We search for the resolved path in the log
if grep -Fq "External Include: $EXTERNAL_ROOT/include" weave.log; then
    echo "✅ [External] External SDK path was reported."
else
    echo "❌ [External] Failed to report external include path."
    echo "   Expected: External Include: $EXTERNAL_ROOT/include"
    echo "--- WEAVE LOG ---"
    cat weave.log
    echo "-----------------"
    exit 1
fi

echo "🎉 Header Weaving Test Passed."
rm -rf "$TEST_DIR"