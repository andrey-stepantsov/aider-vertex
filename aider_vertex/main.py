import os
import sys

def main():
    print("Starting Aider-Vertex...")
    
    args = sys.argv[1:]
    new_args = []
    
    # Handle custom flags before Aider even loads
    for arg in args:
        if arg.startswith("--vertex-project="):
            os.environ["VERTEX_PROJECT"] = arg.split("=")[1]
        elif arg.startswith("--vertex-location="):
            os.environ["VERTEX_LOCATION"] = arg.split("=")[1]
        else:
            new_args.append(arg)

    # Clean the global sys.argv
    sys.argv = [sys.argv[0]] + new_args
    
    # NOW import and run aider
    from aider.main import main as aider_main
    aider_main()

if __name__ == "__main__":
    main()