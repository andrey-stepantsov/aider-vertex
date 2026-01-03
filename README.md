# Aider-Vertex: Agentic C/C++ Development Environment

**Aider-Vertex** is a specialized development environment that bridges [Aider](https://aider.chat/) (using Google Vertex AI / Gemini 1.5 Pro) with a robust, containerized C/C++ toolchain.

It solves the "Context Window Problem" for large monorepos by using **Virtual Views**: dynamically generated, self-contained slices of your codebase that allow the AI to build, test, and debug specific components without being overwhelmed by the entire repository.

## 🚀 Key Features

* **Virtual Views (`weave-view`):** Instantly create a symlinked sandbox containing only the source code relevant to a specific task.
* **Header Weaving:** Automatically analyzes `compile_commands.json` to find and link hidden internal headers, enabling `clang-tidy` and LSP tools to work correctly inside a partial view.
* **The Orchestrator (`./dev`):** A unified script to manage views, link the correct debug daemons (`.ddd`), and launch the AI agent.
* **Triple-Head Debugging:**
    * **Head 1 (AI):** Edits code and runs builds in the container.
    * **Head 2 (Human):** Reviews changes in `view-<name>/` using Neovim/VSCode.
    * **Head 3 (Daemon):** A shared `.ddd` socket manages build locks and test signaling.
* **Hermetic Toolchain:** Powered by **Nix** and **Devbox** to ensure identical tools (GCC, Clang, CMake, Python) on macOS and Linux.

---

## 🛠️ Installation

**Prerequisites:**
1.  [Nix](https://nixos.org/download.html) (Package Manager)
2.  [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) (Environment Manager)
3.  Google Cloud Credentials (for Vertex AI)

**Setup:**
```bash
# 1. Clone the repo
git clone https://github.com/your-username/aider-vertex.git
cd aider-vertex

# 2. Enter the Shell (Installs all dependencies)
devbox shell
# or if using direnv:
direnv allow
```

---

## 🎮 Usage

### 1. The "Full" Mode
To work on the entire repository (useful for architectural refactors):
```bash
./dev full
```

### 2. Targeted Views (Recommended)
To work on a specific component (e.g., "backend"), first define a **Target**:

**File:** `targets/backend.txt`
```text
src/backend
libs/common
tests/backend_tests.cpp
```

Then, launch the orchestrator:
```bash
./dev backend
```
**What happens next?**
1.  The script creates `view-backend/`.
2.  It symlinks only the paths listed in `targets/backend.txt`.
3.  It scans `compile_commands.json` and automatically links required headers (Header Weaving).
4.  It launches Aider inside `view-backend/`, treating it as the repo root.

### 3. Verification & Tests
The project includes a full regression suite to verify the environment, path rewriting, and weaving logic.

```bash
./tests/run_all.sh
```

---

## 🏗️ Architecture

### Directory Structure
```text
.
├── bin/                # Custom Tools (weave-view, weave-headers)
├── targets/            # User-defined view definitions (*.txt)
├── tests/              # Regression Suite (Unit & Integration)
├── dev                 # The Orchestrator Script
├── devbox.json         # Environment Definition
├── flake.nix           # Nix Dependency Lock
└── view-*/             # (Git Ignored) Generated Virtual Views
```

### The "Git Bridge"
Even though Aider runs inside `view-backend/`, it still commits to your real git repository. The orchestrator sets `GIT_DIR` and `GIT_WORK_TREE` environment variables so the AI's commits are applied to the real source files, not the symlinks.

---

## 🔧 Troubleshooting

* **"Weave-view not found":** Ensure you are inside the `devbox shell`.
* **Clang-Tidy errors:** Run `./dev <target>` again. The "Header Weaver" runs automatically on startup to catch new includes.
* **Docker/Path issues:** The tools automatically rewrite host paths (macOS `/var/...`) to container paths. If issues persist, check `tests/unit/test_docker_rewrite.sh`.