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

      cargoDeps = unstable.rustPlatform.fetchCargoVendor {
        inherit (final.rpds-py) src;
        name = "rpds-py-vendor";
        hash = "sha256-2skrDC80g0EKvTEeBI4t4LD7ZXb6jp2Gw+owKFrkZzc=";
      };
      
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        # Use STABLE hook (prevents 'concatTo' shell errors)
        pkgs.rustPlatform.maturinBuildHook
        pkgs.rustPlatform.cargoSetupHook
        # Include UNSTABLE tools in path
        unstable.cargo
        unstable.rustc
      ];

      # CRITICAL: Force maturin/cargo hooks to use the UNSTABLE binaries
      # This fixes the "lock file version 4" error by using a modern Cargo
      CARGO = "${unstable.cargo}/bin/cargo";
      RUSTC = "${unstable.rustc}/bin/rustc";

      # FIX: Manually unpack because poetry2nix incorrectly assumes this is a wheel
      unpackPhase = ''
        echo ">>> Manual UnpackPhase: Extracting $src"
        tar -xf $src
        srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
        if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
        echo ">>> Setting sourceRoot to $srcDir"
        export sourceRoot="$srcDir"
      '';

      # Disable poetry2nix's default wheel unpack logic
      wheelUnpackPhase = "true"; 
    });

    watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
  };

  # ---------------------------------------------------------------------------
  # 2. MACOS: Only applied on Darwin (Manual Wheels)
  # ---------------------------------------------------------------------------
  darwin = if pkgs.stdenv.isDarwin then {} else {};

  # ---------------------------------------------------------------------------
  # 3. LINUX: Only applied on Linux (Source builds & Manylinux fixes)
  # ---------------------------------------------------------------------------
  linux = if pkgs.stdenv.isLinux then {
    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });
  } else {};

in
  common // darwin // linux