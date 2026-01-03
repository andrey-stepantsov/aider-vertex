#!/usr/bin/env bash
set -e

# verify_arch.sh - Automated Regression Test for Triple-Head Architecture

echo "🧪 Starting Architecture Verification..."

# --- 1. Cleanup & Setup ---
echo "   [1/5] Cleaning previous state..."
rm -rf tutorial-stub bin/aider-vertex-mock
# Ensure local bin is in path
export PATH=$PWD/bin:$PATH

# --- 2. Generate Stub (REAL RUN) ---
# We run this BEFORE mocking, using the python module directly to be safe.
echo "   [2/5] Generating Nested Monorepo..."
python -m aider_vertex.main --gen-tutorial > /dev/null

if [ ! -d "tutorial-stub" ]; then
    echo "❌ Error: Failed to generate tutorial-stub."
    exit 1
fi

# --- 3. Mocking Aider ---
# NOW we create the mock to intercept the 'dev' script calls.
echo "   [3/5] Mocking Aider binary..."
MOCK_BIN="bin/aider-vertex"

# Save the real binary if it exists (for safety, though we are likely in devbox/git)
if [ -f "$MOCK_BIN" ] && [ ! -f "$MOCK_BIN.bak" ]; then
    mv "$MOCK_BIN" "$MOCK_BIN.bak"
fi

cat <<'EOF' > "$MOCK_BIN"
#!/bin/bash
echo "   🤖 [MOCK-AIDER] Started successfully."
echo "   🤖 [MOCK-AIDER] Root: $2" # The --root flag is usually the 2nd arg
# Check if we can see the expected build command
if [ -f ".ddd/config.json" ]; then
    CMD=$(grep "cmd" .ddd/config.json | head -n 1)
    echo "   🤖 [MOCK-AIDER] Visible Build Cmd: $CMD"
fi
EOF
chmod +x "$MOCK_BIN"

# --- 4. Run Tests ---
cd tutorial-stub

# --- Test Case A: Root View ---
echo "   [4/5] Testing Target: ROOT (Should use Global Daemon)"
../dev root > root_log.txt 2>&1

if grep -q "Relinking View" root_log.txt; then
    echo "   ❌ FAILURE: Root view should NOT have relinked .ddd!"
    cat root_log.txt
    # Restore binary before exiting
    cd ..
    [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

LINK_TARGET=$(readlink view-root/.ddd)
# We look for the absolute path ending in /tutorial-stub/.ddd
if [[ "$LINK_TARGET" == *"/tutorial-stub/.ddd" ]]; then
    echo "   ✅ Success: view-root is linked to Global Daemon."
else
    echo "   ❌ FAILURE: view-root linked to wrong daemon: $LINK_TARGET"
    # Restore binary before exiting
    cd ..
    [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

# --- Test Case B: Nested Library View ---
echo "   [5/5] Testing Target: LIB1 (Should use Nested Daemon)"
../dev lib1 > lib_log.txt 2>&1

if ! grep -q "Relinking View" lib_log.txt; then
    echo "   ❌ FAILURE: Lib1 view DID NOT relink to nested .ddd!"
    cat lib_log.txt
    # Restore binary before exiting
    cd ..
    [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

LINK_TARGET=$(readlink view-lib1/.ddd)
if [[ "$LINK_TARGET" == *"/tutorial-stub/libs/lib1/.ddd" ]]; then
    echo "   ✅ Success: view-lib1 is linked to Nested Daemon."
else
    echo "   ❌ FAILURE: view-lib1 linked to wrong daemon: $LINK_TARGET"
    # Restore binary before exiting
    cd ..
    [ -f "$MOCK_BIN.bak" ] && mv "$MOCK_BIN.bak" "$MOCK_BIN"
    exit 1
fi

# --- Cleanup ---
cd ..
# Restore the real binary
if [ -f "$MOCK_BIN.bak" ]; then
    mv "$MOCK_BIN.bak" "$MOCK_BIN"
else
    rm "$MOCK_BIN" # If it didn't exist before (e.g. poetry shim), just delete mock
fi

echo ""
echo "🎉 ALL TESTS PASSED. Architecture is verified."