Here is the full content for `overrides.nix`.

This version includes the robust `preBuild` logic to handle the directory mismatch, along with debug logging so we can see exactly where the build lands if it fails again.

```nix
{ pkgs, googleFix, unstable }:
final: prev:
let
  # ---------------------------------------------------------------------------
  # 1. COMMON: Applies to both macOS and Linux
  # ---------------------------------------------------------------------------
  common = {
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    rpds-py = prev.rpds-py.overridePythonAttrs (old: {
      preferWheel = false; 
      src = pkgs.fetchPypi {
        pname = "rpds_py";
        version = "0.22.3";
        hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
      };

      # FIX: Use fetchCargoVendor from unstable (required for new lockfiles)
      cargoDeps = unstable.rustPlatform.fetchCargoVendor {
        inherit (final.rpds-py) src;
        name = "rpds-py-vendor";
        hash = "sha256-2skrDC80g0EKvTEeBI4t4LD7ZXb6jp2Gw+owKFrkZzc=";
      };
      
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        # CRITICAL: Use STABLE hook to match shell, but UNSTABLE compiler for v4 lockfiles
        pkgs.rustPlatform.maturinBuildHook
        unstable.cargo
        unstable.rustc
      ];

      # FIX: Robustly find the source directory.
      # poetry2nix's phase handling can sometimes leave us in /build root.
      preBuild = ''
        echo ">>> [Debug] preBuild Start. Current Directory: $(pwd)"
        ls -la
        
        # Try to enter the source dir if it exists
        if [ -d "rpds_py-0.22.3" ]; then
          echo ">>> Found rpds_py-0.22.3, entering..."
          cd rpds_py-0.22.3
        elif [ -d "rpds-py-0.22.3" ]; then
          echo ">>> Found rpds-py-0.22.3, entering..."
          cd rpds-py-0.22.3
        else
          echo ">>> WARNING: Could not find expected source directory. Attempting build in current dir."
        fi
        
        echo ">>> [Debug] Final Build Directory: $(pwd)"
      '';
    });

    watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
  };

  # ---------------------------------------------------------------------------
  # 2. MACOS: Only applied on Darwin (Manual Wheels)
  # ---------------------------------------------------------------------------
  darwin = if pkgs.stdenv.isDarwin then {
    # Place your yarl/shapely/tokenizers manual wheel blocks here if they exist
    # ...
  } else {};

  # ---------------------------------------------------------------------------
  # 3. LINUX: Only applied on Linux (Source builds & Manylinux fixes)
  # ---------------------------------------------------------------------------
  linux = if pkgs.stdenv.isLinux then {
     # <--- TEll AIDER TO EDIT INSIDE THIS SET ONLY
    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });
  } else {};

in
  # Merge the sets (Linux overrides take precedence over Common if duplicates exist)
  common // darwin // linux

```