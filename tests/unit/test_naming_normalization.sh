#!/bin/bash
set -e

# Setup Mock Environment
TEST_DIR=$(mktemp -d)
# We simulate the Repo Root inside tmp to avoid touching your real targets/ folder
MOCK_REPO="$TEST_DIR/repo"
mkdir -p "$MOCK_REPO/targets"
mkdir -p "$MOCK_REPO/bin"

# Copy the dev script to the mock repo so it runs relative to the mock targets
cp dev "$MOCK_REPO/dev"
DEV_SCRIPT="$MOCK_REPO/dev"

# 1. Mock 'weave-view' 
# FIX: Mock must behave like real weaver -> prepend 'view-' if missing
cat <<'MOCK' > "$MOCK_REPO/bin/weave-view"
#!/bin/bash
INPUT_NAME="$1"
if [[ "$INPUT_NAME" == view-* ]]; then 
    VIEW_NAME="$INPUT_NAME"
else 
    VIEW_NAME="view-$INPUT_NAME"
fi

mkdir -p "$VIEW_NAME"
echo "[MOCK-WEAVE] Weaving $VIEW_NAME"
MOCK
# chmod +x might not work on mounts, but we are in /tmp (native linux), so it should. 
# However, explicit invocation is safer.
chmod +x "$MOCK_REPO/bin/weave-view"

# 2. Mock 'aider-vertex'
cat <<'MOCK' > "$MOCK_REPO/bin/aider-vertex"
#!/bin/bash
echo "[MOCK-AIDER] Launched in $(pwd)"
MOCK
chmod +x "$MOCK_REPO/bin/aider-vertex"

# 3. Create Targets
echo "src" > "$MOCK_REPO/targets/foo.txt"
echo "src" > "$MOCK_REPO/targets/view-bar.txt"

# 4. Setup Environment
# Prepend Mock Bin to PATH
export PATH="$MOCK_REPO/bin:$PATH"

echo "🧪 Testing Orchestrator Naming Normalization..."
echo "   Mock Repo: $MOCK_REPO"

# Debug: Ensure we are picking up the mocks
LOC=$(which aider-vertex)
if [[ "$LOC" != "$MOCK_REPO/bin/aider-vertex" ]]; then
    echo "❌ ERROR: Mock not active! 'which aider-vertex' returned: $LOC"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Switch to mock repo so ./dev finds ./targets
cd "$MOCK_REPO"

# --- CASE 1: Standard Name (foo) ---
echo "   [1/2] Testing target 'foo' -> expect 'view-foo'"
# FIX: Use 'bash ./dev' explicitly to avoid Shebang/Permission issues in Docker
if OUTPUT_1=$(timeout 2s bash ./dev foo 2>&1); then
    if echo "$OUTPUT_1" | grep -q "Launched in .*view-foo$"; then
        echo "   ✅ Success: 'foo' resolved to 'view-foo'"
    else
        echo "   ❌ FAILED: 'foo' did not resolve correctly."
        echo "   Output: $OUTPUT_1"
        exit 1
    fi
else
    echo "   ❌ TIMEOUT/FAIL: ./dev foo crashed or hung."
    echo "   Output: $OUTPUT_1"
    exit 1
fi

# --- CASE 2: Prefixed Name (view-bar) ---
echo "   [2/2] Testing target 'view-bar' -> expect 'view-bar' (NOT view-view-bar)"
if OUTPUT_2=$(timeout 2s bash ./dev view-bar 2>&1); then
    if echo "$OUTPUT_2" | grep -q "Launched in .*view-bar$"; then
        echo "   ✅ Success: 'view-bar' resolved to 'view-bar' (Idempotent)"
    else
        echo "   ❌ FAILED: 'view-bar' was double-prefixed."
        echo "   Output: $OUTPUT_2"
        exit 1
    fi
else
    echo "   ❌ TIMEOUT/FAIL: ./dev view-bar crashed or hung."
    echo "   Output: $OUTPUT_2"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"
echo "🎉 Naming Normalization Test Passed."