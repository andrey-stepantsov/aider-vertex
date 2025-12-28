{ pkgs, googleFix, unstable }:
final: prev:
{
  # ... Google overrides ...
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

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
      unstable.gfortran
    ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
    
    # Try adding the specific lib path for link time
    buildInputs = (old.buildInputs or []) ++ [ unstable.gfortran.cc.lib ];
    
    # Inject LDFLAGS for both meson env and linker
    preConfigure = (old.preConfigure or "") + ''
      export FC=${unstable.gfortran}/bin/gfortran
      export LIBRARY_PATH="${unstable.gfortran.cc.lib}/lib:$LIBRARY_PATH"
      export LDFLAGS="-L${unstable.gfortran.cc.lib}/lib -Wl,-rpath,${unstable.gfortran.cc.lib}/lib $LDFLAGS"
      # Meson specific env vars
      export FFLAGS="$LDFLAGS"
    '';

    preferWheel = true;
    configurePhase = "true"; 
  });

  # Rpds-py override for Darwin (unchanged, it works)
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
        unstable.cargo unstable.rustc unstable.maturin pkgs.python311Packages.pip pkgs.pkg-config
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
        export PATH="${unstable.cargo}/bin:${unstable.rustc}/bin:$PATH"
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