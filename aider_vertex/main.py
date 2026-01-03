import sys
import os
import yaml
import tempfile
from importlib import metadata
from aider.main import main as aider_main
from .doctor import check_health
from .tutorial import generate_tutorial

WRAPPER_VERSION = "1.2.0"

def get_aider_version():
    try:
        return metadata.version("aider-chat")
    except metadata.PackageNotFoundError:
        return "unknown"

def generate_dynamic_config():
    """
    Generates a .aider.conf.yml on the fly with absolute paths
    resolved for the current environment.
    This ensures 'test-cmd' always points to the correct .ddd/wait
    regardless of which subdirectory Aider is launched in.
    """
    # Attempt to locate .ddd/wait in the current or parent directories
    # Logic: Start at CWD, look up.
    cwd = os.getcwd()
    wait_cmd = None
    
    # Simple heuristic: Look in current dir, then assume we are in a view (so look one up)
    if os.path.exists(os.path.join(cwd, ".ddd", "wait")):
        wait_cmd = os.path.join(cwd, ".ddd", "wait")
    elif os.path.exists(os.path.join(os.path.dirname(cwd), ".ddd", "wait")):
        wait_cmd = os.path.join(os.path.dirname(cwd), ".ddd", "wait")
    
    # Default Config tailored for Vertex/DDD
    config = {
        "auto-commits": True,
        "attribute-commit-message-author": True,
        "attribute-author": True,
    }

    if wait_cmd:
        config["test-cmd"] = wait_cmd
        print(f"   [i] Configured test-cmd: {wait_cmd}")

    # Write to a temp file
    fd, path = tempfile.mkstemp(prefix="aider_vertex_", suffix=".yml", text=True)
    with os.fdopen(fd, 'w') as f:
        yaml.dump(config, f)
    
    return path

def main():
    # 1. Special Flags
    if "--version" in sys.argv:
        aider_ver = get_aider_version()
        print(f"aider-vertex {WRAPPER_VERSION} (engine: aider-chat v{aider_ver})")
        sys.exit(0)

    if "--gen-tutorial" in sys.argv:
        generate_tutorial()
        sys.exit(0)

    # 2. The Doctor
    # We run this on every launch to prevent "silent failures"
    if not check_health():
        print("⚠️  Proceeding despite health check failures... (Ctrl+C to abort)")

    # 3. Dynamic Configuration
    # Only generate if user hasn't explicitly supplied a config file
    if "--config" not in sys.argv:
        config_path = generate_dynamic_config()
        print(f"⚙️  Generated dynamic config: {config_path}")
        sys.argv.extend(["--config", config_path])

    # 4. Delegate to Aider
    try:
        aider_main()
    except Exception:
        # Clean exit for Aider interruptions
        sys.exit(1)

if __name__ == "__main__":
    main()
