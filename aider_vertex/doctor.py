import os
import sys
import shutil
import time
from pathlib import Path

def check_health():
    """
    Performs pre-flight checks for the Aider-Vertex environment.
    Verifies Credentials, Toolchain, and the DDD Interface (v0.6.0+).
    Returns True if healthy, False otherwise.
    """
    print("👨‍⚕️  Running Pre-Flight Checks (The Doctor)...")
    issues = []
    warnings = []

    # --- 1. Credentials & Environment ---
    creds = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    project = os.environ.get("VERTEXAI_PROJECT")
    location = os.environ.get("VERTEXAI_LOCATION")

    if not creds:
        issues.append("❌ GOOGLE_APPLICATION_CREDENTIALS not set.")
    elif not os.path.exists(creds):
        issues.append(f"❌ Credential file not found at: {creds}")
    else:
        print("   [✓] Auth: Credentials found.")

    if not project or not location:
        issues.append("❌ VERTEXAI_PROJECT and VERTEXAI_LOCATION must be set.")
    else:
        print(f"   [✓] Vertex: {project} ({location})")

    # --- 2. Toolchain Verification ---
    required_tools = ["git", "jq", "weave-view"]
    missing_tools = [t for t in required_tools if not shutil.which(t)]
    
    if missing_tools:
        issues.append(f"❌ Missing critical tools in PATH: {', '.join(missing_tools)}")
    else:
        print("   [✓] Toolchain: git, jq, weave-view found.")

    # --- 3. DDD Interface (v0.6.0 Project-Local) ---
    # Logic: Walk up from CWD to find .ddd
    cwd = Path.cwd()
    ddd_dir = None
    
    # Search up to 3 levels up to find the interface
    for parent in [cwd] + list(cwd.parents)[:3]:
        candidate = parent / ".ddd"
        if candidate.is_dir():
            ddd_dir = candidate
            break

    if ddd_dir:
        # Check 3A: Writability (Critical for signaling)
        if not os.access(ddd_dir, os.W_OK):
            issues.append(f"❌ DDD Interface found at {ddd_dir} but is NOT WRITABLE.")
        else:
            print(f"   [✓] DDD: Interface linked at {ddd_dir}")
            
        # Check 3B: Runtime State (v0.6.0+)
        # The daemon now uses .ddd/run/ for locks and logs.
        run_dir = ddd_dir / "run"
        ipc_lock = run_dir / "ipc.lock"
        
        # Check for legacy lock file (Migration Warning)
        legacy_lock = ddd_dir / "run.lock"
        if legacy_lock.exists():
             warnings.append(f"⚠️  Legacy lock file found ({legacy_lock}). Please delete it.")

        # Check for active IPC lock
        if ipc_lock.exists():
            # If lock is older than 5 minutes, warn
            if time.time() - ipc_lock.stat().st_mtime > 300:
                warnings.append(f"⚠️  Stale IPC lock detected ({ipc_lock}). The daemon might be stuck.")
            else:
                print("   [i] Daemon is currently BUSY (IPC lock active).")
        
        # Check for Build Log
        build_log = run_dir / "build.log"
        if build_log.exists():
             print(f"   [i] Build log found ({build_log}).")

    else:
        # It is valid to run without DDD (e.g. standard Aider use), but worthy of a warning
        # if the user expects the "Triple-Head" integration.
        warnings.append("⚠️  No .ddd directory found. 'Parasitic Mode' (Build/Verify) will not work.")

    # --- 4. Git Bridge Integrity (View Mode) ---
    # If we are inside a 'view-*' directory, we expect GIT_DIR to be set by ./dev
    if cwd.name.startswith("view-") or cwd.parent.name.startswith("view-"):
        if not os.environ.get("GIT_DIR"):
             warnings.append("⚠️  Running inside a 'view' but GIT_DIR is not set. Git operations might fail.")
        else:
            print("   [✓] Git Bridge: Active.")

    # --- Reporting ---
    if warnings:
        print("\n🤔 Warnings:")
        for w in warnings:
            print(w)

    if issues:
        print("\n🚨 Doctor found CRITICAL issues:")
        for issue in issues:
            print(issue)
        print("")
        return False
    
    print("   [✓] System Healthy.\n")
    return True
