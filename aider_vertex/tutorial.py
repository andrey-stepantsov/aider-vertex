import os
import subprocess
from pathlib import Path

TUTORIAL_DIR = "tutorial-stub"

# --- File Content Assets ---

C_MATH_H = """#ifndef LIB_H
#define LIB_H
int add(int a, int b);
#endif
"""

C_MATH_C = """#include "lib.h"
int add(int a, int b) {
    return a + b;
}
"""

C_MAIN_C = """#include <stdio.h>
#include "../../core/math/lib.h"

int main() {
    int result = add(2, 2);
    printf("Result: %d\\n", result);
    return 0;
}
"""

MAKEFILE = """
CC = gcc
# Simulated complex include path
CFLAGS = -Isrc/core/math

# VPATH handles the deep nesting resolution for Make
VPATH = src/apps/cli src/core/math

OBJS = main.o lib.o

all: cli

cli: $(OBJS)
    $(CC) $(CFLAGS) -o $@ $^

clean:
    rm -f *.o cli
"""

DDD_CONFIG = """{
  "targets": {
    "dev": {
      "build": {
        "cmd": "make",
        "filter": ["gcc_make", "gcc_json"]
      },
      "verify": {
        "cmd": "./cli",
        "filter": "raw"
      }
    }
  }
}
"""

GITIGNORE = """
cli
*.o
.ddd/build.log
.ddd/*.lock
"""

def generate_tutorial():
    """Generates a complex monorepo stub for path resolution testing."""
    base = Path(TUTORIAL_DIR)
    if base.exists():
        print(f"❌ Error: Directory '{TUTORIAL_DIR}' already exists.")
        return

    print(f"🏗  Generating Complex Monorepo Stub: {TUTORIAL_DIR} ...")
    
    # 1. Structure
    (base / "src/core/math").mkdir(parents=True)
    (base / "src/apps/cli").mkdir(parents=True)
    (base / "targets").mkdir(parents=True)
    (base / ".ddd").mkdir(parents=True)

    # 2. Source Code
    (base / "src/core/math/lib.h").write_text(C_MATH_H)
    (base / "src/core/math/lib.c").write_text(C_MATH_C)
    (base / "src/apps/cli/main.c").write_text(C_MAIN_C)

    # 3. Build System
    (base / "Makefile").write_text(MAKEFILE)
    (base / ".gitignore").write_text(GITIGNORE)
    (base / ".ddd/config.json").write_text(DDD_CONFIG)

    # 4. Orchestrator Targets
    # This defines the "files of interest" for the orchestrator script
    (base / "targets/full.txt").write_text("src/apps/cli\nsrc/core/math")
    (base / "targets/backend.txt").write_text("src/core/math")

    # 5. Git Init
    try:
        subprocess.run(["git", "init"], cwd=base, check=True, stdout=subprocess.DEVNULL)
        print("   [✓] Initialized git repo")
    except FileNotFoundError:
        print("   [!] Git not found, skipping init.")

    print(f"\n✅ Tutorial Ready at: {base.resolve()}")
    print(f"👉 Next Step: cd {TUTORIAL_DIR} && ../dev full")