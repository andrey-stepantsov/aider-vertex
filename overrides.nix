{ pkgs, googleFix, unstable }:
final: prev:
let
  # ===========================================================================
  # LINUX OVERRIDES
  # Strategies: 
  # 1. Strip hooks from unstable tools to prevent "concatTo: command not found".
  # 2. Use dummy Python packages for Meson/Ninja to satisfy Pip's dependency 
  #    checks while using the binary tools.
  # ===========================================================================
  linuxOverrides = let
    cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
    cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });
  in {
    # Fix Google Cloud packages
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    # 1. Dummy Meson for Linux
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

    # 2. Dummy Ninja for Linux
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
    
    scipy = prev.scipy.overridePythonAttrs (old: {
      nativeBuildInputs = (pkgs.lib.filter 
        (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
        (old.nativeBuildInputs or [])) 
      ++ [ final.meson final.ninja unstable.pkg-config unstable.gfortran ];
      preferWheel = true;
      configurePhase = "true";
    });

    # Watchfiles on Linux needs special care for anyio
    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });

    # Rpds-py override (Same as before)
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
        ];
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
  };

  # ===========================================================================
  # DARWIN OVERRIDES
  # Strategies:
  # 1. Use the REAL unstable meson (Python app). macOS doesn't crash on hooks,
  #    so we can just use the real package which satisfies pip.
  # 2. Explicitly handle Fortran linking (LDFLAGS) to fix "not runnable" errors.
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

    # On macOS, just use unstable meson directly. It has correct metadata.
    meson = unstable.meson;
    ninja = unstable.ninja;

    scipy = prev.scipy.overridePythonAttrs (old: {
      # Use unstable tools (for version requirements) but STABLE Fortran (for system compat)
      nativeBuildInputs = (pkgs.lib.filter 
        (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
        (old.nativeBuildInputs or [])) 
      ++ [
        unstable.meson 
        unstable.ninja
        unstable.pkg-config
        pkgs.gfortran
      ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
      
      # FIX: macOS Gfortran Linking
      # We explicitly inject the library path into LDFLAGS to help dyld find libgfortran
      buildInputs = (old.buildInputs or []) ++ [ pkgs.gfortran.cc.lib ];
      
      preConfigure = (old.preConfigure or "") + ''
        export LDFLAGS="-L${pkgs.gfortran.cc.lib}/lib -Wl,-rpath,${pkgs.gfortran.cc.lib}/lib $LDFLAGS"
        # Sometimes setting FC helps meson find the right wrapper
        export FC=${pkgs.gfortran}/bin/gfortran
      '';

      preferWheel = true;
      configurePhase = "true"; 
    });

    # Copy of RPDS override for Darwin (same logic)
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