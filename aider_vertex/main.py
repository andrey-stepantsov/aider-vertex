import sys
from aider.main import main as aider_main
from importlib import metadata

# Your wrapper version (synced with pyproject.toml)
WRAPPER_VERSION = "1.1.5"

def get_aider_version():
    """Extracts the version of the underlying aider-chat package."""
    try:
        return metadata.version("aider-chat")
    except metadata.PackageNotFoundError:
        return "unknown"

def main():
    # 1. Handle Version Request
    if "--version" in sys.argv:
        aider_ver = get_aider_version()
        print(f"aider-vertex {WRAPPER_VERSION} (engine: aider-chat v{aider_ver})")
        sys.exit(0)

    # 2. Delegate everything else to Aider
    # We call Aider's official entry point with the current sys.argv
    aider_main()

if __name__ == "__main__":
    main()
