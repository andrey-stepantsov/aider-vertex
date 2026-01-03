# Project Roadmap

## ✅ Completed (v1.2.0)
- [x] **Triple-Head Architecture:** Implemented `weave-view` orchestrator.
- [x] **Header Weaving:** Implemented `weave-headers` (Python) to scan `compile_commands.json` and symlink headers.
- [x] **Nix Flake:** Fully hermetic build for macOS (Darwin) and Linux.
- [x] **Docker Support:** Validated cross-compilation workflow for Apple Silicon (M1/M2).
- [x] **Regression Suite:**
    - [x] Unit Tests: Path rewriting, Header weaving, Naming normalization.
    - [x] Integration Test: Full architecture verification with nested Git repo generation.
    - [x] Cross-Platform: Suite runs on both host macOS and inside Linux Docker containers.

## 🚀 Upcoming (v1.3.0)
- [ ] **Dependency Graphing:** Use `cscope` or `clang-query` to pull in `.c` implementation files (not just headers) for deeper context.
- [ ] **Ghost-Writing:** Allow the AI to "request" files it cannot see, triggering a dynamic fetch into the Virtual View.
- [ ] **LSP Integration:** Hook up `clangd` inside the Virtual View to validate AI edits before they are committed.
- [ ] **CI Automation:** Move the `docker run` regression test into GitHub Actions.

## 🐛 Known Issues / Notes
- **Git Identity in Tests:** The integration test sets a dummy global git identity when running inside Docker. This is protected by a check for `/.dockerenv`.
- **Permissions:** When running tests in Docker via volume mounts, `chmod +x` is unreliable. Mocks are generated in `/tmp` to work around this.
