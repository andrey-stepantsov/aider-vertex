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

    # FIX: Upgrade meson in the python set to unstable (>=1.5.0) for Scipy.
    # We strip the setupHook to prevent "concatTo: command not found" errors
    # which occur when unstable hooks run in a stable stdenv.
    meson = prev.meson.overrideAttrs (old: {
      src = unstable.meson.src;
      version = unstable.meson.version;
      patches = []; # Clear stable patches that don't apply to new version
      setupHook = null; # Disable incompatible hooks
    });

    # FIX: Upgrade ninja to avoid similar hook issues.
    ninja = prev.ninja.overrideAttrs (old: {
      src = unstable.ninja.src;
      version = unstable.ninja.version;
      setupHook = null; 
    });

    # FIX: Scipy 1.15.3 requires newer meson.
    scipy = prev.scipy.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        final.meson # Use our clean, updated meson
        final.ninja # Use our clean, updated ninja
        unstable.pkg-config
        unstable.gfortran
      ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.Accelerate
      ];
      
      # Prefer wheel if available to avoid build altogether
      preferWheel = true;
      
      # Disable Nix's automatic meson configure phase. Let pip handle it.
      configurePhase = "true";
    });

    rpds-py = prev.rpds-py.overridePythonAttrs (old: 
      let
        # Fetch dependencies using the unstable fetcher (required for v4 lockfiles)
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

        srcCargoDeps = rustDeps;
        
        # Disable automatic Rust hooks to prevent version conflicts.
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          unstable.cargo
          unstable.rustc
          unstable.maturin      # Use binary directly
          pkgs.python311Packages.pip # Needed for install phase
          pkgs.pkg-config       # Helper for finding system libs
        ];

        # Add macOS-specific system libraries required for linking
        buildInputs = (old.buildInputs or []) ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.libiconv
          pkgs.darwin.apple_sdk.frameworks.Security
          pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        ];

        # FIX: Manual Unpack
        # poetry2nix mistakenly treats the tarball as a wheel, creating empty dirs.
        unpackPhase = ''
          echo ">>> Manual UnpackPhase: Extracting $src"
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
          echo ">>> Setting sourceRoot to $srcDir"
          export sourceRoot="$srcDir"
        '';

        # FIX: Manual Configure (Vendor setup)
        # Bypasses cargoSetupHook validation logic
        preConfigure = ''
          echo ">>> Manual Cargo Config"
          mkdir -p .cargo
          cat > .cargo/config.toml <<EOF
          [source.crates-io]
          replace-with = "vendored-sources"

          [source.vendored-sources]
          directory = "$srcCargoDeps"
          EOF
          export CARGO_HOME=$(pwd)/.cargo
          
          # MacOS Fix: Explicitly point to libiconv using Nix string interpolation
          ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
             export RUSTFLAGS="-L ${pkgs.libiconv}/lib -l iconv"
          ''}
        '';

        # FIX: Manual Build using Maturin directly
        # Bypasses maturinBuildHook which was using the wrong (stable) Cargo version
        buildPhase = ''
          echo ">>> Manual BuildPhase with Maturin"
          export PATH="${unstable.cargo}/bin:${unstable.rustc}/bin:$PATH"
          maturin build --release --jobs $NIX_BUILD_CORES --strip -i python3
        '';

        # FIX: Manual Install & Satisfy poetry2nix dist expectations
        installPhase = ''
          echo ">>> Manual InstallPhase"
          mkdir -p $out
          
          # Find the built wheel
          wheel=$(find target/wheels -name "*.whl" | head -n 1)
          if [ -z "$wheel" ]; then echo "❌ Error: No wheel found"; exit 1; fi
          
          echo ">>> Installing $wheel"
          pip install --no-deps --prefix=$out "$wheel"
          
          # CRITICAL FIX: poetry2nix's pythonOutputDistPhase expects the built artifacts in ./dist
          # If we don't put them there, the build fails after installation.
          echo ">>> Copying wheel to ./dist for poetry2nix compliance"
          mkdir -p dist
          cp "$wheel" dist/
        '';

        # Disable all automatic phases we replaced
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