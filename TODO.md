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
- [x] **Implement "The Doctor" (Pre-Flight Checks)**
    - **Status:** **Done.**
    - **Details:** `aider-vertex` now runs `check_health()` on startup. Verifies Credentials, Toolchain, and DDD Interface writability. Warns on stale locks or missing `.ddd`.

- [x] **Dynamic Configuration Generation**
    - **Status:** **Done.**
    - **Details:** `main.py` generates a temporary `.aider.conf.yml` at runtime, resolving the absolute path to `test-cmd` (`.ddd/wait`) relative to the current view.

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