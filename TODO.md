# Project TODOs

## 🧠 Feature Enhancements
- [x] **Implement `--gen-tutorial` Flag**
    - **Status:** **Done.**
    - **Details:** `aider-vertex --gen-tutorial` generates a nested monorepo stub with `mk`/`lmk` scripts to verify path resolution.

- [x] **Implement `./dev` Orchestrator & Target Management**
    - **Status:** **Done.**
    - **Details:** The `dev` script parses targets, weaves views, manages the Git Bridge, and intelligently links nested `.ddd` configs.

- [x] **Implement Nested DDD Linking (Multi-View Support)**
    - **Status:** **Done.**
    - **Details:** Verified by `verify_arch.sh`. Support for "Nested Sovereignty" (Global vs. Local Daemons) is active.

## 🛠️ Reliability & "The Doctor"
- [ ] **Implement "The Doctor" (Pre-Flight Checks)**
    - **Goal:** Prevent startup failures by verifying the environment before launching.
    - **Implementation:** Add `check_health` to validate:
        1. `dd-daemon` socket is active.
        2. Essential env vars (`VERTEXAI_PROJECT`, `VERTEXAI_LOCATION`) are set.
        3. `weave-view` binary is in PATH.
    - **Benefit:** Fails fast with helpful error messages.

- [ ] **Dynamic Configuration Generation**
    - **Goal:** Eliminate manual path patching in `.aider.conf.yml`.
    - **Implementation:** Generate a temporary `.aider.conf.yml` at runtime that hardcodes the absolute path to `test-cmd: .../.ddd/wait`.

## 🐛 Bugs & Edge Cases
- [ ] **Analyze Clang-Tidy Include Path Strategy**
    - **Issue:** Views exclude headers needed for local linting (`#include "missing.h"`), causing `clang-tidy` false positives inside Aider.
    - **Mitigation:** Update `targets/` definitions to include header directories, or script a "Header Weaving" step.

- [ ] **Fix `weave-view` Path Mismatch in Docker**
    - **Issue:** Host-generated `compile_commands.json` contains host paths (`/Users/...`) that are invalid inside the Docker container (`/data/...`).
    - **Fix:** Add a `sed` step to `weave-view` to rewrite paths when running in Docker mode.

- [ ] **Fix `weave-view` Redundant Naming**
    - **Issue:** Script double-prefixes names (e.g., `view-view-app`).
    - **Fix:** Check if prefix exists before adding it in `flake.nix`.