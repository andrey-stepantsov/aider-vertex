#!/usr/bin/env bash
set -e

# Resolve Repo Root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$REPO_ROOT"

echo "🧪 Starting Architecture Verification..."
echo "   Working Directory: $(pwd)"

# --- 1. Cleanup & Setup ---
echo "   [1/5] Cleaning previous state..."
rm -rf tutorial-stub

# FIX: Only touch global git config if running inside Docker
if [ -f /.dockerenv ]; then
    echo "   [i] Docker detected: Configuring dummy git identity..."
    git config --global user.email "bot@aider-vertex.test"
    git config --global user.name "Test Bot"
    git config --global init.defaultBranch main
fi

# --- 2. Generate Stub ---
echo "   [2/5] Generating Nested Monorepo..."
if command -v aider-vertex &> /dev/null; then
    aider-vertex --gen-tutorial > /dev/null
else
    # Local fallback: ensure we use the project's python environment
    python3 -m aider_vertex.main --gen-tutorial > /dev/null
fi

if [ ! -d "tutorial-stub" ]; then
    echo "❌ Error: Failed to generate tutorial-stub."
    exit 1
fi

# --- 3. Mocking Aider ---
echo "   [3/5] Mocking Aider binary..."

# Use /tmp for mock to ensure +x permissions work everywhere
MOCK_DIR=$(mktemp -d)
MOCK_BIN="$MOCK_DIR/aider-vertex"

# Use #!/bin/bash for portability
cat <<'MOCK' > "$MOCK_BIN"
#!/bin/bash
echo "   🤖 [MOCK-AIDER] Started successfully."
echo "   🤖 [MOCK-AIDER] Root: $2" 
if [ -f ".ddd/config.json" ]; then
    CMD=$(grep "cmd" .ddd/config.json | head -n 1)
    echo "   🤖 [MOCK-AIDER] Visible Build Cmd: $CMD"
fi
MOCK

chmod +x "$MOCK_BIN"

# Prepend to PATH
export PATH="$MOCK_DIR:$PATH"

# --- 4. Run Tests ---
cd tutorial-stub

# --- Test Case A: Root View ---
echo "   [4/5] Testing Target: ROOT (Should use Global Daemon)"
if ! timeout 5s bash ../dev root > root_log.txt 2>&1; then
    echo "   ❌ TIMEOUT or CRASH: ../dev root failed."
    cat root_log.txt
    exit 1
fi

if grep -q "Relinking View" root_log.txt; then
    echo "   ❌ FAILURE: Root view should NOT have relinked .ddd!"
    cat root_log.txt
    exit 1
fi

LINK_TARGET=$(readlink view-root/.ddd)
if [[ "$LINK_TARGET" == *"/tutorial-stub/.ddd" ]]; then
    echo "   ✅ Success: view-root is linked to Global Daemon."
else
    echo "   ❌ FAILURE: view-root linked to wrong daemon: $LINK_TARGET"
    cat root_log.txt
    exit 1
fi

# --- Test Case B: Nested Library View ---
echo "   [5/5] Testing Target: LIB1 (Should use Nested Daemon)"
if ! timeout 5s bash ../dev lib1 > lib_log.txt 2>&1; then
    echo "   ❌ TIMEOUT or CRASH: ../dev lib1 failed."
    cat lib_log.txt
    exit 1
fi

if ! grep -q "Relinking View" lib_log.txt; then
    echo "   ❌ FAILURE: Lib1 view DID NOT relink to nested .ddd!"
    cat lib_log.txt
    exit 1
fi

LINK_TARGET=$(readlink view-lib1/.ddd)
if [[ "$LINK_TARGET" == *"/tutorial-stub/libs/lib1/.ddd" ]]; then
    echo "   ✅ Success: view-lib1 is linked to Nested Daemon."
else
    echo "   ❌ FAILURE: view-lib1 linked to wrong daemon: $LINK_TARGET"
    exit 1
fi

# --- Cleanup ---
cd ..
rm -rf "$MOCK_DIR"
rm -rf tutorial-stub

echo ""
echo "🎉 ALL TESTS PASSED. Architecture is verified."