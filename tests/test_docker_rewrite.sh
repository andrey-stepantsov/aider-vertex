#!/bin/bash
set -e

# Setup locations
REPO_ROOT="$(pwd)"
TEST_DIR=$(mktemp -d)
BIN_WEAVE="$REPO_ROOT/bin/weave-view"

echo "🧪 Testing weave-view Docker Path Rewrite logic..."
echo "   Mock Container Dir: $TEST_DIR"

# 1. Create Mock Source Structure
# We simulate that we are inside the Docker container at $TEST_DIR
mkdir -p "$TEST_DIR/src"
touch "$TEST_DIR/src/main.c"

# 2. Create "Host" compile_commands.json
# Pretend the host was at /Users/developer/project
HOST_ROOT="/Users/developer/project"
CONTAINER_ROOT="$TEST_DIR"

cat <<EOF > "$TEST_DIR/compile_commands.json"
[
  {
    "directory": "$HOST_ROOT",
    "command": "gcc -c src/main.c",
    "file": "$HOST_ROOT/src/main.c"
  }
]
EOF

# 3. Run weave-view inside the "Container"
# We ask it to view 'src/main.c'. 
# The script MUST detect that the JSON path ($HOST_ROOT) doesn't match PWD ($CONTAINER_ROOT)
# and rewrite it BEFORE applying the filter.
cd "$TEST_DIR"
"$BIN_WEAVE" test_view src/main.c > weave.log 2>&1

# 4. Verification
OUTPUT_JSON="view-test_view/compile_commands.json"

if [ ! -f "$OUTPUT_JSON" ]; then
    echo "❌ FAILED: compile_commands.json was not generated."
    echo "--- Log ---"
    cat weave.log
    exit 1
fi

# Check if the path was rewritten to the container root
# We look for the resolved path: $TEST_DIR/src/main.c
if grep -q "$CONTAINER_ROOT/src/main.c" "$OUTPUT_JSON"; then
    echo "✅ SUCCESS: Path rewritten correctly."
    echo "   Found: $(grep 'file' $OUTPUT_JSON)"
else
    echo "❌ FAILED: Path was NOT rewritten."
    echo "   Expected Prefix: $CONTAINER_ROOT"
    echo "   Actual JSON Content:"
    cat "$OUTPUT_JSON"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"