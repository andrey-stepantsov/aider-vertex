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
- [x] **Fix `weave-view` Path Mismatch in Docker**
    - **Status:** **Done.**
    - **Details:** `weave-view` now auto-detects path mismatches between the host JSON and the container environment, using `sed` to rewrite paths to `/data` before filtering.

- [x] **Analyze Clang-Tidy Include Path Strategy**
    - **Status:** **Done.**
    - **Details:** Implemented `weave-headers` (Python) to parse `compile_commands.json` and symlink repo-internal headers into `_sys/includes`. External headers are reported to stdout. Verified with `tests/unit/test_header_weaving.sh`.

- [x] **Fix `weave-view` Redundant Naming**
    - **Status:** **Done.**
    - **Details:** Updated `./dev` script to check if the target name already starts with `view-` before prepending it. Verified with `tests/unit/test_naming_normalization.sh`.