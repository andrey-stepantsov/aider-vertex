import os
import sys

def check_health():
    """
    Performs pre-flight checks for the Aider-Vertex environment.
    Returns True if healthy, False otherwise.
    """
    print("👨‍⚕️  Running Pre-Flight Checks (The Doctor)...")
    issues = []

    # 1. Credentials
    creds = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not creds:
        issues.append("❌ GOOGLE_APPLICATION_CREDENTIALS not set.")
    elif not os.path.exists(creds):
        issues.append(f"❌ Credential file not found at: {creds}")
    else:
        print("   [✓] Auth: Credentials found.")

    # 2. Vertex Config
    project = os.environ.get("VERTEXAI_PROJECT")
    location = os.environ.get("VERTEXAI_LOCATION")
    if not project:
        issues.append("❌ VERTEXAI_PROJECT not set.")
    if not location:
        issues.append("❌ VERTEXAI_LOCATION not set.")
    
    if project and location:
        print(f"   [✓] Vertex: {project} ({location})")

    # 3. DDD Interface (The Triple Head)
    # Check if we are in a valid root by looking for .ddd
    # Note: If running inside a view, we check the parent or assume the mount is correct.
    cwd = os.getcwd()
    ddd_dir = os.path.join(cwd, ".ddd")
    
    # Simple check: assumes we are running from root or .ddd is available
    if os.path.isdir(ddd_dir):
        print(f"   [✓] DDD: Found .ddd interface in {cwd}")
    else:
        # If we are in a view-*, the .ddd might be one level up or not symlinked yet
        # This is just a warning, as parasitic mode might not be required for all runs.
        print(f"   [!] Info: No .ddd directory found in {cwd}.")
        print("       (If using Parasitic Mode, ensure you are in the project root)")

    # Report
    if issues:
        print("\n🚨 Doctor found critical issues:")
        for issue in issues:
            print(issue)
        return False
    
    print("   [✓] System Healthy.\n")
    return True