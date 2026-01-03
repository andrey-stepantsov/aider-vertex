#!/bin/bash
set -e

# Setup Mock Environment
TEST_DIR=$(mktemp -d)
# Resolve absolute paths
REPO_ROOT=$(pwd)
# We execute the script using bash explicitly to avoid shebang/permission issues on volume mounts
BIN_WEAVE="$REPO_ROOT/bin/weave-view"

echo "🧪 Testing weave-view Docker Path Rewrite logic..."
echo "   Mock Container Dir: $TEST_DIR"

# 1. Create Structure in the Temp Dir (Simulating the Docker Container Filesystem)
mkdir -p "$TEST_DIR/src"
touch "$TEST_DIR/src/main.c"

# 2. Create compile_commands.json with HOST PATHS (Simulating the mismatch)
# We use a fake host path: /Users/developer/project
HOST_ROOT="/Users/developer/project"
CONTAINER_ROOT="$TEST_DIR"

cat <<JSON > "$TEST_DIR/compile_commands.json"
[
  {
    "directory": "$HOST_ROOT/src",
    "command": "gcc -c main.c",
    "file": "$HOST_ROOT/src/main.c"
  }
]
JSON

# 3. Run weave-view
# We switch to the temp dir to simulate running inside the project root
cd "$TEST_DIR"
bash "$BIN_WEAVE" test_view src/main.c > weave.log 2>&1 || true

# 4. Verification

# A. Check if the JSON was generated
TARGET_JSON="view-test_view/compile_commands.json"
if [ ! -f "$TARGET_JSON" ]; then
    echo "❌ Failed to generate compile_commands.json"
    echo "--- LOG ---"
    cat weave.log
    exit 1
fi

# B. Check for Path Rewrite
# We expect the generated JSON to contain the CONTAINER path ($TEST_DIR), NOT the HOST path
if grep -q "$CONTAINER_ROOT" "$TARGET_JSON"; then
    echo "✅ Host path was correctly rewritten to container path."
else
    echo "❌ Path rewrite failed."
    echo "   Expected: $CONTAINER_ROOT"
    echo "   Found in JSON:"
    cat "$TARGET_JSON"
    echo "--- LOG ---"
    cat weave.log
    exit 1
fi

rm -rf "$TEST_DIR"