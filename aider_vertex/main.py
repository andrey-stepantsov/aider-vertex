import sys
from aider.main import main as aider_main

def main():
    # No interception, no hardcoding.
    # Just pass whatever the user typed directly to the aider engine.
    aider_main()

if __name__ == "__main__":
    main()