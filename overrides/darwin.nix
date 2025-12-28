{ pkgs, googleFix, unstable }:
final: prev:
{
  # Standard Google Fixes
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  # Use Unstable tools (macOS handles them fine)
  meson = unstable.meson;
  ninja = unstable.ninja;

  scipy = prev.scipy.overridePythonAttrs (old: {
    nativeBuildInputs = (pkgs.lib.filter 
      (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
      (old.nativeBuildInputs or [])) 
    ++ [
      unstable.meson 
      unstable.ninja
      unstable.pkg-config
      pkgs.gfortran # Use STABLE Gfortran to match system libs
    ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
    
    # Link against STABLE libraries
    buildInputs = (old.buildInputs or []) ++ [ pkgs.gfortran.cc.lib ];
    
    preConfigure = (old.preConfigure or "") + ''
      export FC=${pkgs.gfortran}/bin/gfortran
      # Aggressive Linking to find libgfortran
      export DYLD_LIBRARY_PATH="${pkgs.gfortran.cc.lib}/lib:$DYLD_LIBRARY_PATH"
      export DYLD_FALLBACK_LIBRARY_PATH="${pkgs.gfortran.cc.lib}/lib:$DYLD_FALLBACK_LIBRARY_PATH"
      export LDFLAGS="-L${pkgs.gfortran.cc.lib}/lib -Wl,-rpath,${pkgs.gfortran.cc.lib}/lib $LDFLAGS"
    '';

    preferWheel = true;
    configurePhase = "true"; 
  });

  # Use old-school override with STABLE Rust to avoid Python version mismatch
  rpds-py = prev.rpds-py.overridePythonAttrs (old: 
    let
      rustDeps = pkgs.rustPlatform.fetchCargoVendor {
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
      cargoDeps = rustDeps;
      # Using STABLE Rust/Maturin
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        pkgs.cargo pkgs.rustc pkgs.maturin pkgs.python311Packages.pip pkgs.pkg-config
        pkgs.libiconv pkgs.darwin.apple_sdk.frameworks.Security pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
      ];
      buildInputs = (old.buildInputs or []) ++ [ pkgs.libiconv ];
      preConfigure = ''
         mkdir -p .cargo
         cat > .cargo/config.toml <<EOF
         [source.crates-io]
         replace-with = "vendored-sources"
         [source.vendored-sources]
         directory = "$srcCargoDeps"
         EOF
         export CARGO_HOME=$(pwd)/.cargo
         export RUSTFLAGS="-L ${pkgs.libiconv}/lib -l iconv"
      '';
      buildPhase = ''
        export PATH="${pkgs.cargo}/bin:${pkgs.rustc}/bin:$PATH"
        maturin build --release --jobs $NIX_BUILD_CORES --strip -i python3
      '';
      installPhase = ''
        mkdir -p $out
        wheel=$(find target/wheels -name "*.whl" | head -n 1)
        pip install --no-deps --prefix=$out "$wheel"
        mkdir -p dist && cp "$wheel" dist/
      '';
      wheelUnpackPhase = "true"; 
  });
  
  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
}