# Aider-Vertex (v1.1.5)

**Aider-Vertex** is a Dockerized AI coding environment powered by Google Vertex AI (Gemini models). It is specifically engineered for refactoring **Legacy C/C++ Embedded Systems** where build dependencies (proprietary SDKs, old compilers) are complex and fragile.

## 🚀 Quick Start: The "Silver Bullet" Command

To launch the environment with full access to your host's toolchains and SDKs, use this command. It mounts the necessary read-only paths so the AI sees the exact same headers as your build system.

```bash
docker run -it --rm \
  --entrypoint bash \
  \
  # 1. Mount Source Code (Read/Write)
  -v /repos/prj0/system0:/repos/prj0/system0 \
  -w /repos/prj0/system0 \
  \
  # 2. Mount Legacy Toolchains (Read-Only)
  -v /opt/rh:/opt/rh:ro \
  -v /auto/swtools:/auto/swtools:ro \
  -v /usr/include:/usr/include:ro \
  -v /usr/local/include:/usr/local/include:ro \
  \
  # 3. Credentials
  -v /tmp/auth.json:/root/auth.json \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/auth.json \
  -e VERTEXAI_PROJECT="your-project-id" \
  -e VERTEXAI_LOCATION="us-central1" \
  \
  # 4. [Optional] Mission Pack (External Scripts)
  -v /path/to/my/local/scripts:/mission/bin:ro \
  \
  ghcr.io/andrey-stepantsov/aider-vertex:v1.1.5
```

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

### Phase 2: Isolation (`weave-view`)
Don't let Aider scan your entire 10GB repo. Create a virtual view containing **only** the file and its unit test.

```bash
# Syntax: weave-view <name> <impl_file> <test_file>
weave-view amem-fix \
  modules/infra/amem \
  modules/infra/amem/ut
```

### Phase 3: The Refactoring Loop
Enter the view and start the AI.

```bash
cd view-amem-fix
aider-vertex
```

**Inside the Chat:**
1.  Paste the **System Context** (from `cc-pick`).
2.  Use the **Mission Pack** scripts to verify changes automatically.
    ```text
    /run verify.sh
    ```

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
| **`weave-view <name> ...`** | Creates a lightweight workspace of symlinks + a filtered `compile_commands.json`. |
| **`show-targets`** | (Deprecated) Legacy alias for `cc-targets`. |

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
