import os
import sys

def main():
    print("Starting Aider-Vertex...")
    
    # We create a brand new list and explicitly filter out our custom flags
    # We also handle the values before they are deleted
    clean_args = []
    clean_args.append(sys.argv[0]) # Keep the program name
    
    for arg in sys.argv[1:]:
        if arg.startswith("--vertex-project="):
            os.environ["VERTEX_PROJECT"] = arg.split("=")[1]
        elif arg.startswith("--vertex-location="):
            os.environ["VERTEX_LOCATION"] = arg.split("=")[1]
        elif "--vertex" in arg:
            # Catch-all for any other vertex-related flag variants
            pass
        else:
            clean_args.append(arg)

    # REWRITE sys.argv entirely
    sys.argv[:] = clean_args
    
    # Debug: Confirm what we are passing to Aider
    # print(f"DEBUG: Args passed to Aider: {sys.argv}")
    
    from aider.main import main as aider_main
    aider_main()

if __name__ == "__main__":
    main()