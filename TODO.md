# Project TODOs

## 🧠 Feature Enhancements (New)
- [ ] **Implement `--gen-tutorial` Flag**
    - **Goal:** Allow users to bootstrap a test environment without cloning the repo or finding external scripts.
    - **Behavior:**
        1. When `aider-vertex --gen-tutorial` is run:
        2. Check if the current directory is safe (empty or explicitly allowed).
        3. Write the `tutorial-stub/` file structure (Makefile, src/app, src/math, .ddd/config, targets/) to `$PWD`.
        4. Initialize a git repo locally (if git is available).
        5. Exit with instructions: "Run './dev full' to start."
    - **Benefit:** Works identically in Docker (`-v $(pwd):/data`) and Nix (`$PWD`), zero dependencies.

- [ ] **Auto-Init Ephemeral Git Session**
    - **Issue:** When running in `weave-view` (no `.git` folder), Aider defaults to `--no-git`, disabling `/undo`, auto-commits, and diffs.
    - **Goal:** Automatically initialize a temporary, session-local git environment on startup.
    - **Implementation Details:**
        1. Entrypoint checks if `.git` exists in `/data`.
        2. If not:
           - Run `git init`.
           - Configure a dummy user (e.g., `user.email "aider@session.local"`).
           - Create a baseline commit (`git add . && git commit -m "Baseline"`).
    - **Benefit:** Restores full Aider capabilities (safe experimentation with undo) without risking the actual monorepo history.

## 🛠️ Deployment & Experience
- [ ] **Implement `./dev` Orchestrator & Target Management**
    - **Goal:** Create a single entry point for managing views and launching the environment.
    - **Implementation:**
        1. **Presets:** Create a `targets/` directory to store file lists (e.g., `app1.txt`, `network.txt`).
        2. **Orchestration:** Create a `./dev` script that:
           - Accepts a target name (e.g., `./dev app1`).
           - Reads the pattern from `targets/app1.txt`.
           - Runs `./weave-view` with those patterns.
           - Checks/Starts `dd-daemon` if needed.
           - Launches `aider-vertex` into the generated view.
    - **Benefit:** Zero-friction context switching (e.g., just type `./dev network`).

- [ ] **Implement "The Doctor" (Pre-Flight Checks)**
    - **Goal:** Prevent startup failures by verifying the environment before launching the container.
    - **Implementation:** Add a `check_health` function to `launch-aider.sh` that validates:
        1. `dd-daemon` is running (via `pgrep`).
        2. Essential env vars (`VERTEXAI_PROJECT`, `VERTEXAI_LOCATION`) are set.
        3. Docker daemon is accessible.
    - **Benefit:** Fails fast with helpful error messages instead of mysterious timeouts.

- [ ] **Dynamic Configuration Generation**
    - **Goal:** Eliminate manual path patching in `.aider.conf.yml` when switching between Views and Root.
    - **Implementation:**
        1. Remove `.aider.conf.yml` from version control.
        2. In `launch-aider.sh`, generate a temporary config file (e.g., `.generated.aider.conf.yml`) at runtime.
        3. Hardcode absolute paths (e.g., `test-cmd: /data/.ddd/wait`) in this generated file.
        4. Mount it into the container as `/data/.aider.conf.yml`.
    - **Benefit:** Ensures `test-cmd` always works regardless of the directory Aider starts in.

## 🐛 Bugs & Reliability
- [ ] **Fix `weave-view` Path Mismatch in Docker**
    - **Issue:** Host-generated `compile_commands.json` paths do not match Docker paths, resulting in empty context.
    - **Short-term Fix:** Warn if `compile_commands.json` is empty.
    - **Long-term Fix:** Add path rewriting (Host -> Container paths).

- [ ] **Fix `weave-view` Redundant Naming**
    - **Issue:** Script double-prefixes names (e.g., `view-view-app`).
    - **Fix:** Check if prefix exists before adding it in `flake.nix`.