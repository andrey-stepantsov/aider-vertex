# Aider-Vertex (v1.1.5)

**Aider-Vertex** is a Dockerized AI coding environment powered by Google Vertex AI (Gemini models). It is specifically engineered for refactoring **Legacy C/C++ Embedded Systems** where build dependencies (proprietary SDKs, old compilers) are complex and fragile.

## 🚀 Quick Start: The Orchestrator

We use a "View-Based" development workflow. Instead of opening the entire repo, you open a targeted view defined in `targets/` files. This isolates the AI, preventing it from scanning irrelevant code while maintaining a "Triple-Head" link to your central build system.

### 1. Define a Target
Create a file in `targets/` listing the source directories for your task.
**File: `targets/backend.txt`**
```text
src/core/math
src/libs/utils
```

### 2. Launch the Environment
Run the orchestrator script to weave the view and start the AI.
```bash
./dev backend
```
* **Creates:** `view-backend/` (Symlinks to source)
* **Links:** `.ddd/` (Connects to the global Build Daemon)
* **Launches:** Aider with restricted vision but full Git capabilities.

### 3. The Refactoring Loop
Inside the Aider chat, you have full control:
* **Edit:** `src/core/math/lib.c` (Changes reflect in real repo)
* **Verify:** `/test` (Runs the global `.ddd/wait` script)
* **Commit:** `/commit` (Commits to the real Git repo)

---

## 🛠 The Workflow: Refactoring Legacy Code

This image includes a custom toolkit designed to bridge the gap between "Modern AI" and "Legacy Makefiles."

### Phase 1: Audit & Context (`cc-*` Tools)
Legacy builds often compile the same file 5+ times (Sim, Chip A, Chip B). You must identify the **Golden Master** target to prevent the AI from hallucinating on conflicting flags.

1.  **List Targets:** See all build variations for a file.
    ```bash
    cc-targets modules/infra/amem/amem_tree.c
    ```
    *Look for the "Hardware" target (e.g., `-DARCH_FIJI`) with the most flags.*

2.  **Inspect Flags (Optional):** Compare includes/defines if unsure.
    ```bash
    cc-flags modules/infra/amem/amem_tree.c "^-D"
    ```

3.  **Pick Context:** Extract the **single** JSON entry for the AI.
    ```bash
    cc-pick modules/infra/amem/amem_tree.c fiji
    ```
    *Copy the output JSON. You will paste this into the Aider chat as "System Context".*

### Phase 2: Orchestration (`./dev`)
Don't let Aider scan your entire 10GB repo. Use the `./dev` script to create a "View" that contains **only** the relevant files.

* **View Creation:** `weave-view` creates a folder of symlinks.
* **Git Bridge:** The environment automatically maps Git commands back to your real repo.
* **Build Bridge:** The `.ddd` folder is linked, so `/test` runs your real Makefiles.

### Phase 3: The Triple-Head Architecture
When you run `./dev backend`, the system adapts to your project structure:

1.  **Global Context:** If your target relies on the root build system, it links the root `.ddd` config (e.g., running `make`).
2.  **Nested Sovereignty:** If your target is a library with its own `.ddd` configuration (e.g., `libs/lib1/.ddd`), the orchestrator detects this and links the *local* daemon instead.
3.  **Isolation:** Aider runs inside the view, seeing only the files you specified, but retains full capability to commit to the main Git repository.

---

## 🧰 Included Tools

### Context Managers (New in v1.1.5)
| Tool | Description |
| :--- | :--- |
| **`cc-targets <file>`** | Lists every build target (Sim/Hw) found in `compile_commands.json` for a specific file. |
| **`cc-flags <file> [regex]`** | Dumps raw compiler flags for inspection. Filter with regex (e.g., `^-I` for includes). |
| **`cc-pick <file> <key>`** | Extracts the raw JSON block for a specific target keyword. **Crucial for AI Context.** |

### Workspace Managers
| Tool | Description |
| :--- | :--- |
| **`./dev <target>`** | The main entry point. Weaves a view, links the correct daemon, and launches Aider. |
| **`weave-view <name> ...`** | (Internal) Creates a lightweight workspace of symlinks + a filtered `compile_commands.json`. |

### Mission Packs (`/mission/bin`)
You can inject your own shell scripts into the container at runtime by mounting a folder to `/mission/bin`.
* Scripts in this folder are automatically added to `$PATH`.
* Use this for `verify.sh`, `lint.sh`, or custom build wrappers.
* **Zero Pollution:** Scripts disappear when the container stops.

---

## ⚙️ Configuration

### Clang-Tidy (Legacy Handling)
Legacy code often triggers "C11 vs C99" warnings in modern linters. Create a `.clang-tidy` in your repo root to suppress noise:

```yaml
Checks: "-*,clang-diagnostic-*, -clang-diagnostic-typedef-redefinition"
```

### Authentication
Ensure your `auth.json` (Service Account Key) has permissions for **Vertex AI User**.

---

## 🏗 Development (Nix)

To build the image locally or modify the tools:

```bash
# Enter the dev shell (contains all tools + python env)
nix develop

# Build the Docker image
nix build .#docker
docker load < result
```

### Architecture Verification
This repository includes an automated regression test to verify the "Triple-Head" logic (View Weaving + Git Bridge + Nested Daemon Linking).

```bash
# Runs the full verification suite (generates stub, tests orchestrator)
./verify_arch.sh
```