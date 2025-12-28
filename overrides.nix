{ pkgs, googleFix, unstable }:
final: prev:
let
  # ---------------------------------------------------------------------------
  # Helper: Clean unstable tools without their hooks
  # ---------------------------------------------------------------------------
  # We need the binaries from unstable, but their setup hooks are incompatible 
  # with the stable stdenv (missing 'concatTo', expecting specific file layouts).
  # So we strip the hooks.
  mesonNew = unstable.meson.overrideAttrs (old: {
    setupHook = null;
  });
  
  ninjaNew = unstable.ninja.overrideAttrs (old: {
    setupHook = null;
  });

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

    # FIX: Scipy 1.15.3 requires newer meson (>=1.5.0).
    scipy = prev.scipy.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        mesonNew  # Unstable binary, NO hook
        ninjaNew  # Unstable binary, NO hook
        unstable.pkg-config
        unstable.gfortran
      ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.Accelerate
      ];

      # Disable Nix's automatic meson configure phase.
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
        unpackPhase = ''
          echo ">>> Manual UnpackPhase: Extracting $src"
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
          echo ">>> Setting sourceRoot to $srcDir"
          export sourceRoot="$srcDir"
        '';

        # FIX: Manual Configure (Vendor setup)
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
  common // darwin // linux