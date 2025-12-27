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

    rpds-py = prev.rpds-py.overridePythonAttrs (old: 
      let
        # Fetch dependencies using the unstable fetcher
        rustDeps = unstable.rustPlatform.fetchCargoVendor {
          inherit (final.rpds-py) src;
          name = "rpds-py-vendor";
          hash = "sha256-2skrDC80g0EKvTEeBI4t4LD7ZXb6jp2Gw+owKFrkZzc=";
        };
      in {
        preferWheel = false; 
        src = pkgs.fetchPypi {
          pname = "rpds_py";
          version = "0.22.3";
          hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
        };

        # Explicitly tell the hook where the vendor dir is
        cargoVendorDir = rustDeps;
        
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          # Stable maturin hook
          pkgs.rustPlatform.maturinBuildHook
          # Unstable cargo setup hook (required for fetchCargoVendor)
          unstable.rustPlatform.cargoSetupHook
          # Unstable toolchain (required for v4 Cargo.lock)
          unstable.cargo
          unstable.rustc
        ];

        CARGO = "${unstable.cargo}/bin/cargo";
        RUSTC = "${unstable.rustc}/bin/rustc";

        # FIX: Manual unpack + Lockfile Hack
        # 1. Unpack the tarball.
        # 2. Find the directory.
        # 3. COPY the Cargo.lock to the root of the build dir so the setup hook finds it.
        unpackPhase = ''
          echo ">>> Manual UnpackPhase: Extracting $src"
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
          
          echo ">>> Found source dir: $srcDir"
          
          # HACK: cargoSetupHook looks for Cargo.lock in the current dir ($PWD)
          # even if we set sourceRoot. So we put a copy right here.
          cp "$srcDir/Cargo.lock" Cargo.lock
          
          echo ">>> Setting sourceRoot to $srcDir"
          export sourceRoot="$srcDir"
        '';

        wheelUnpackPhase = "true"; 
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