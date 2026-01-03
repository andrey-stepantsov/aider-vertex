import os
import stat
import subprocess
from pathlib import Path

TUTORIAL_DIR = "tutorial-stub"

# --- 1. Root Scripts (Global Context) ---
ROOT_MK = """#!/bin/bash
echo "🔨 [ROOT] Running Global Build (mk)..."
# Simulates building the whole world
if [ -d "libs/lib1" ]; then
    echo "   -> Building submodule: lib1"
    ./libs/lib1/lmk
else
    echo "   [!] Error: libs/lib1 missing"
    exit 1
fi
echo "✅ [ROOT] Build Complete."
"""

ROOT_TEST = """#!/bin/bash
echo "🧪 [ROOT] Running Global Verification (test)..."
# Simulates a full integration test
if ./libs/lib1/test/run; then
    echo "✅ [ROOT] All Tests Passed."
    exit 0
else
    exit 1
fi
"""

ROOT_DDD_CONFIG = """{
  "targets": {
    "dev": {
      "build": { "cmd": "./mk", "filter": ["raw"] },
      "verify": { "cmd": "./test", "filter": ["raw"] }
    }
  }
}
"""

ROOT_WAIT = """#!/bin/bash
# Root Daemon Interface
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "🔍 [Daemon-Root] Checking Global Build..."
./mk && ./test
"""

# --- 2. Library Scripts (Nested Context) ---
LIB_LMK = """#!/bin/bash
echo "   🔨 [LIB1] Running Library Build (lmk)..."
# Simulate gcc compilation of the local lib
gcc -c src/math.c -o math.o
echo "   ✅ [LIB1] Lib compiled."
"""

LIB_TEST_RUN = """#!/bin/bash
echo "   🧪 [LIB1] Running Unit Tests (test/run)..."
# Simulate running a unit test binary
if [ -f "math.o" ]; then
    echo "      [PASS] Math object exists."
    exit 0
else
    echo "      [FAIL] Math object missing!"
    exit 1
fi
"""

LIB_DDD_CONFIG = """{
  "targets": {
    "dev": {
      "build": { "cmd": "./lmk", "filter": ["raw"] },
      "verify": { "cmd": "./test/run", "filter": ["raw"] }
    }
  }
}
"""

LIB_WAIT = """#!/bin/bash
# Library Daemon Interface
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 [Daemon-Lib1] Checking Library Build..."
cd "$LIB_ROOT"
./lmk && ./test/run
"""

# --- 3. Source Code ---
LIB_MATH_C = """#include <stdio.h>
int add(int a, int b) { return a + b; }
"""

def generate_tutorial():
    """Generates the Nested Monorepo Stub with custom mk/lmk scripts."""
    base = Path(TUTORIAL_DIR)
    if base.exists():
        print(f"❌ Error: Directory '{TUTORIAL_DIR}' already exists.")
        return

    print(f"🏗  Generating Nested Monorepo Stub: {TUTORIAL_DIR} ...")
    
    # 1. Create Directory Structure
    # Root
    (base / ".ddd").mkdir(parents=True)
    (base / "targets").mkdir(parents=True)
    
    # Nested Library
    lib_dir = base / "libs/lib1"
    (lib_dir / "src").mkdir(parents=True)
    (lib_dir / "test").mkdir(parents=True)
    (lib_dir / ".ddd").mkdir(parents=True)

    # 2. Generate Root Files
    _write_script(base / "mk", ROOT_MK)
    _write_script(base / "test", ROOT_TEST)
    (base / ".ddd/config.json").write_text(ROOT_DDD_CONFIG)
    _write_script(base / ".ddd/wait", ROOT_WAIT)
    
    # 3. Generate Library Files
    _write_script(lib_dir / "lmk", LIB_LMK)
    _write_script(lib_dir / "test/run", LIB_TEST_RUN)
    (lib_dir / "src/math.c").write_text(LIB_MATH_C)
    (lib_dir / ".ddd/config.json").write_text(LIB_DDD_CONFIG)
    _write_script(lib_dir / ".ddd/wait", LIB_WAIT)

    # 4. Generate Target Definitions
    # Target 1: The Root View (should use root .ddd)
    (base / "targets/root.txt").write_text("mk\ntest\nlibs/lib1")
    
    # Target 2: The Nested Library View (should use lib1 .ddd)
    (base / "targets/lib1.txt").write_text("libs/lib1/src\nlibs/lib1/test")

    # 5. Git Init (Standard Bridge)
    try:
        subprocess.run(["git", "init"], cwd=base, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["git", "add", "."], cwd=base, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["git", "commit", "-m", "Initial commit"], cwd=base, check=True, stdout=subprocess.DEVNULL)
        print("   [✓] Initialized git repo")
    except Exception:
        print("   [!] Git init skipped")

    print(f"\n✅ Tutorial Ready at: {base.resolve()}")
    print("👉 Test Scenarios:")
    print("   1. Root View:  ../dev root  (Should run './mk')")
    print("   2. Lib View:   ../dev lib1  (Should run './lmk')")

def _write_script(path: Path, content: str):
    path.write_text(content)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)