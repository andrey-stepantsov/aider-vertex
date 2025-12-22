import sys
from aider.main import main as aider_main

def main():
    # No more complex logic here. Nix has already set the ENV 
    # and added the --model flag to the command line.
    aider_main()

if __name__ == "__main__":
    main()