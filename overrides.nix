{ pkgs, googleFix, unstable }:
final: prev:
let
  # Linux Helpers
  cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
  cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });

  linuxOverrides = {
    # ... Google overrides ...
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    # 1. Dummy Meson (Linux)
    meson = pkgs.python311Packages.buildPythonPackage {
      pname = "meson";
      version = unstable.meson.version;
      format = "other";
      src = ./.; 
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        ln -s ${cleanMesonBinary}/bin/meson $out/bin/meson
        site_packages=$out/lib/python3.11/site-packages
        mkdir -p $site_packages/meson-${unstable.meson.version}.dist-info
        echo "Metadata-Version: 2.1" > $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
        echo "Name: meson" >> $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
        echo "Version: ${unstable.meson.version}" >> $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
        ln -s ${cleanMesonBinary}/lib/python*/site-packages/mesonbuild $site_packages/mesonbuild
      '';
      propagatedBuildInputs = [ cleanMesonBinary ];
    };

    # 2. Dummy Ninja (Linux)
    ninja = pkgs.python311Packages.buildPythonPackage {
      pname = "ninja";
      version = unstable.ninja.version;
      format = "other";
      src = ./.; 
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        ln -s ${cleanNinjaBinary}/bin/ninja $out/bin/ninja
        site_packages=$out/lib/python3.11/site-packages
        mkdir -p $site_packages/ninja-${unstable.ninja.version}.dist-info
        echo "Metadata-Version: 2.1" > $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
        echo "Name: ninja" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
        echo "Version: ${unstable.ninja.version}" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
      '';
      propagatedBuildInputs = [ cleanNinjaBinary ];
    };

    meson-python = prev.meson-python.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.meson ];
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ final.meson ];
    });

    # Fix pybind11 on Linux (needs ninja)
    pybind11 = prev.pybind11.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.ninja ];
    });
    
    scipy = prev.scipy.overridePythonAttrs (old: {
      nativeBuildInputs = (pkgs.lib.filter 
        (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
        (old.nativeBuildInputs or [])) 
      ++ [ final.meson final.ninja unstable.pkg-config unstable.gfortran ];
      preferWheel = true;
      configurePhase = "true";
    });

    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });

    # Rpds-py override for Linux (Fixed format)
    rpds-py = prev.rpds-py.overridePythonAttrs (old: 
      let
        rustDeps = unstable.rustPlatform.fetchCargoVendor {
          inherit (final.rpds-py) src;
          name = "rpds-py-vendor";
          hash = "sha256-2skrDC80g0EKvTEeBI4t4LD7ZXb6jp2Gw+owKFrkZzc=";
        };
      in {
        preferWheel = false; 
        format = "pyproject"; # Force source build
        src = pkgs.fetchPypi {
          pname = "rpds_py";
          version = "0.22.3";
          hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
        };
        srcCargoDeps = rustDeps;
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          unstable.cargo unstable.rustc unstable.maturin pkgs.python311Packages.pip pkgs.pkg-config
        ];
        unpackPhase = ''
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          export sourceRoot="$srcDir"
        '';
        buildPhase = ''
          export PATH="${unstable.cargo}/bin:${unstable.rustc}/bin:$PATH"
          cd $sourceRoot
          maturin build --release --jobs $NIX_BUILD_CORES --strip -i python3
        '';
        installPhase = ''
          mkdir -p $out
          wheel=$(find target/wheels -name "*.whl" | head -n 1)
          pip install --no-deps --prefix=$out "$wheel"
          mkdir -p dist && cp "$wheel" dist/
        '';
    });
  };

  # ===========================================================================
  # DARWIN OVERRIDES
  # ===========================================================================
  darwinOverrides = {
    # Fix Google Cloud packages
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    # On macOS, use real packages (no hooks issues usually)
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
        unstable.gfortran # Trying UNSTABLE again
      ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
      
      # Try to fix linking by explicit flags
      buildInputs = (old.buildInputs or []) ++ [ unstable.gfortran.cc.lib ];
      
      preConfigure = (old.preConfigure or "") + ''
        export FC=${unstable.gfortran}/bin/gfortran
        export LDFLAGS="-L${unstable.gfortran.cc.lib}/lib -Wl,-rpath,${unstable.gfortran.cc.lib}/lib $LDFLAGS"
      '';

      preferWheel = true;
      configurePhase = "true"; 
    });

    # Copy of RPDS override for Darwin
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
  };
in
  if pkgs.stdenv.isDarwin then darwinOverrides else linuxOverrides