{ pkgs, googleFix, unstable }:
final: prev:
let
  cleanNinja = unstable.ninja.overrideAttrs (old: {
    setupHook = null;
  });

  common = {
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    # FIX: Rebuild 'meson' as a proper Python package from unstable source.
    # This ensures it has valid metadata for pip and satisfies 'meson-python'.
    # We use buildPythonPackage from pkgs (stable) but source from unstable.
    meson = pkgs.python311Packages.buildPythonPackage {
      pname = "meson";
      version = unstable.meson.version;
      src = unstable.meson.src;
      format = "setuptools"; # Meson uses setup.py
      doCheck = false;
    };

    # FIX: Replace 'ninja' Python package with a dummy that provides the binary.
    # The real ninja python package tries to build from source and fails.
    ninja = prev.ninja.overridePythonAttrs (old: {
      format = "other";
      buildCommand = ''
        mkdir -p $out/bin
        ln -s ${cleanNinja}/bin/ninja $out/bin/ninja
        
        # Fake metadata for pip
        site_packages=$out/lib/python3.11/site-packages
        mkdir -p $site_packages/ninja-${unstable.ninja.version}.dist-info
        echo "Metadata-Version: 2.1" > $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
        echo "Name: ninja" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
        echo "Version: ${unstable.ninja.version}" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
      '';
      propagatedBuildInputs = [ cleanNinja ];
    });

    # FIX: meson-python needs meson available.
    meson-python = prev.meson-python.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.meson ];
    });

    # FIX: Scipy 1.15.3 requires newer meson.
    scipy = prev.scipy.overridePythonAttrs (old: {
      # 1. Filter out existing meson/ninja
      # 2. Add our clean/unstable versions.
      nativeBuildInputs = (pkgs.lib.filter 
        (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
        (old.nativeBuildInputs or [])) 
      ++ [
        final.meson 
        final.ninja
        unstable.pkg-config
        pkgs.gfortran # Use STABLE gfortran to fix macOS linking
      ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.Accelerate
      ];
      
      preferWheel = true;
      configurePhase = "true"; 
    });

    # ... rpds-py override ...
    rpds-py = prev.rpds-py.overridePythonAttrs (old: 
      let
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
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          unstable.cargo
          unstable.rustc
          unstable.maturin
          pkgs.python311Packages.pip
          pkgs.pkg-config
        ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.libiconv
          pkgs.darwin.apple_sdk.frameworks.Security
          pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        ];
        buildInputs = (old.buildInputs or []) ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.libiconv
        ];
        unpackPhase = ''
          echo ">>> Manual UnpackPhase: Extracting $src"
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
          echo ">>> Setting sourceRoot to $srcDir"
          export sourceRoot="$srcDir"
        '';
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
          ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
             export RUSTFLAGS="-L ${pkgs.libiconv}/lib -l iconv"
          ''}
        '';
        buildPhase = ''
          echo ">>> Manual BuildPhase with Maturin"
          export PATH="${unstable.cargo}/bin:${unstable.rustc}/bin:$PATH"
          maturin build --release --jobs $NIX_BUILD_CORES --strip -i python3
        '';
        installPhase = ''
          echo ">>> Manual InstallPhase"
          mkdir -p $out
          wheel=$(find target/wheels -name "*.whl" | head -n 1)
          if [ -z "$wheel" ]; then echo "❌ Error: No wheel found"; exit 1; fi
          echo ">>> Installing $wheel"
          pip install --no-deps --prefix=$out "$wheel"
          echo ">>> Copying wheel to ./dist for poetry2nix compliance"
          mkdir -p dist
          cp "$wheel" dist/
        '';
        wheelUnpackPhase = "true"; 
    });

    watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
  };
  
  darwin = if pkgs.stdenv.isDarwin then {} else {};
  linux = if pkgs.stdenv.isLinux then {
    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });
  } else {};
in
  common // darwin // linux