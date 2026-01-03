# Project TODOs

## 🐛 Bugs & Reliability
- [ ] **Fix `weave-view` Path Mismatch in Docker**
    - **Issue:** When running inside Docker (path `/data`) with a Host-generated `compile_commands.json` (path `/Users/...`), `weave-view` filters out all entries because the paths do not match the `startswith` filter. This results in an empty JSON file and zero AI context.
    - **Short-term Fix:** Add a check to `weave-view` that prints a warning if the resulting `compile_commands.json` contains 0 entries.
    - **Long-term Fix:** Add a `--path-map <host_prefix>:<container_prefix>` argument to `weave-view` to rewrite paths on the fly during the merge step.
    - **Auto-magic:** Detect container environment and auto-patch paths if a common prefix mismatch is found.

- [ ] **Fix `weave-view` Redundant Naming**
    - **Issue:** The script unconditionally prepends `view-` to the user-supplied name. If a user runs `weave-view view-app ...`, it creates `view-view-app`, which is confusing.
    - **Fix:** Update `flake.nix` to check if the argument already starts with `view-` before prepending it.

## 🛠️ Deployment & Experience
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

- [ ] **Unified Entry Script (`./dev`)**
    - **Goal:** Reduce startup friction.
    - **Implementation:** Create a master script that:
        1. Checks for/starts the `dd-daemon` in the background.
        2. Sets up a `trap` to kill the daemon on exit.
        3. Launches the `aider-vertex` container.
    - **Benefit:** Single command startup for the entire Triple-Head environment.

## 🧠 Feature Enhancements
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