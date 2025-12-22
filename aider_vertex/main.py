import sys
import os

# AGGRESSIVE STRIP: Do this before ANY other code runs
if any("vertex" in arg for arg in sys.argv):
    filtered_args = [sys.argv[0]]
    for arg in sys.argv[1:]:
        if arg.startswith("--vertex-project="):
            os.environ["VERTEX_PROJECT"] = arg.split("=")[1]
        elif arg.startswith("--vertex-location="):
            os.environ["VERTEX_LOCATION"] = arg.split("=")[1]
        elif "vertex" not in arg:
            filtered_args.append(arg)
    sys.argv[:] = filtered_args

def main():
    # Force the model if not provided
    if "--model" not in sys.argv:
        sys.argv.extend(["--model", "vertex_ai/gemini-1.5-pro"])

    print(f"Starting Aider-Vertex (Project: {os.environ.get('VERTEX_PROJECT', 'unset')})...")
    
    from aider.main import main as aider_main
    aider_main()

if __name__ == "__main__":
    main()