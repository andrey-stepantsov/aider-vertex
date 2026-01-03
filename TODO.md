# Project TODOs

## 🐛 Bugs & Reliability
- [ ] **Fix `weave-view` Path Mismatch in Docker**
    - **Issue:** When running inside Docker (path `/data`) with a Host-generated `compile_commands.json` (path `/Users/...`), `weave-view` filters out all entries because the paths do not match the `startswith` filter. This results in an empty JSON file and zero AI context, with no error message.
    - **Short-term Fix:** Add a check to `weave-view` that prints a warning if the resulting `compile_commands.json` contains 0 entries.
    - **Long-term Fix:** Add a `--path-map <host_prefix>:<container_prefix>` argument to `weave-view` to rewrite paths on the fly during the merge step.
    - **Auto-magic:** Consider detecting if running in a container and auto-patching the paths if a common prefix mismatch is detected.

## 🚀 Enhancements
- [ ] **Support `.aider.conf.yml` Readability**
    - Ensure `weave-view` correctly handles or copies the config file if needed in the view (currently handled by exclusions, but verified context pathing is important).