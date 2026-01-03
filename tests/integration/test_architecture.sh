#!/usr/bin/env bash
set -e

# Resolve Repo Root (Triple-Head Architecture requires running from Root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$REPO_ROOT"

echo "🧪 Starting Architecture Verification..."
echo "   Working Directory: $(pwd)"

# --- 1. Cleanup & Setup ---
echo "   [1/5] Cleaning previous state..."
rm -rf tutorial-stub bin/aider-vertex-mock
# Ensure local bin is in path
export PATH=$PWD/bin:$PATH

# --- 2. Generate Stub (REAL RUN) ---
echo "   [2/5] Generating Nested Monorepo..."
python -m aider_vertex.main --gen-tutorial > /dev/null

if [ ! -d "tutorial-stub" ]; then
    echo "❌ Error: Failed to generate tutorial-stub."
    exit 1
fi

# --- 3. Mocking Aider ---
echo "   [3/5] Mocking Aider binary..."
MOCK_BIN="bin/aider-vertex"

# Save the real binary if it exists
if [ -f "$MOCK_BIN" ] && [ ! -f "$MOCK_BIN.bak" ]; then
    mv "$MOCK_BIN" "$MOCK_BIN.bak"
fi

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

# --- 4. Run Tests ---
cd tutorial-stub

# --- Test Case A: Root View ---
echo "   [4/5] Testing Target: ROOT (Should use Global Daemon)"
../dev root > root_log.txt 2>&1

if grep -q "Relinking View" root_log.txt; then
    echo "   ❌ FAILURE: Root view should NOT have relinked .ddd!"
    cat root_log.txt
    cd ..; [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

LINK_TARGET=$(readlink view-root/.ddd)
if [[ "$LINK_TARGET" == *"/tutorial-stub/.ddd" ]]; then
    echo "   ✅ Success: view-root is linked to Global Daemon."
else
    echo "   ❌ FAILURE: view-root linked to wrong daemon: $LINK_TARGET"
    cd ..; [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

# --- Test Case B: Nested Library View ---
echo "   [5/5] Testing Target: LIB1 (Should use Nested Daemon)"
../dev lib1 > lib_log.txt 2>&1

if ! grep -q "Relinking View" lib_log.txt; then
    echo "   ❌ FAILURE: Lib1 view DID NOT relink to nested .ddd!"
    cat lib_log.txt
    cd ..; [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

LINK_TARGET=$(readlink view-lib1/.ddd)
if [[ "$LINK_TARGET" == *"/tutorial-stub/libs/lib1/.ddd" ]]; then
    echo "   ✅ Success: view-lib1 is linked to Nested Daemon."
else
    echo "   ❌ FAILURE: view-lib1 linked to wrong daemon: $LINK_TARGET"
    cd ..; [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

# --- Cleanup ---
cd ..
if [ -f "$MOCK_BIN.bak" ]; then
    mv "$MOCK_BIN.bak" "$MOCK_BIN"
else
    rm "$MOCK_BIN"
fi

echo ""
echo "🎉 ALL TESTS PASSED. Architecture is verified."
