import os
import sys
from aider.main import main as aider_main

def main():
    print("Starting Aider-Vertex...")
    
    # Simple logic to extract our custom flags
    args = sys.argv[1:]
    new_args = []
    
    for arg in args:
        if arg.startswith("--vertex-project="):
            os.environ["VERTEX_PROJECT"] = arg.split("=")[1]
        elif arg.startswith("--vertex-location="):
            os.environ["VERTEX_LOCATION"] = arg.split("=")[1]
        else:
            new_args.append(arg)

    # Replace sys.argv so aider doesn't see the custom flags
    sys.argv = [sys.argv[0]] + new_args
    
    aider_main()

if __name__ == "__main__":
    main()