{ pkgs, googleFix, unstable }:
final: prev:
let
  # Wrap unstable binaries to look like Python packages
  cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
  cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });
in
{
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  # Dummy tools
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

  # Inject dummy ninja
  pybind11 = prev.pybind11.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.ninja ];
  });

  # Ensure meson-python finds dummy meson
  meson-python = prev.meson-python.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.meson ];
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ final.meson ];
  });

  scipy = prev.scipy.overridePythonAttrs (old: {
    nativeBuildInputs = (pkgs.lib.filter 
      (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
      (old.nativeBuildInputs or [])) 
    ++ [
      final.meson 
      final.ninja
      unstable.pkg-config
      unstable.gfortran # Switched to UNSTABLE gfortran
    ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
    
    buildInputs = (old.buildInputs or []) ++ [ unstable.gfortran.cc.lib ];
    
    # Aggressive Linking to find Unstable libgfortran
    preConfigure = (old.preConfigure or "") + ''
      export MACOSX_DEPLOYMENT_TARGET=11.0
      export FC=${unstable.gfortran}/bin/gfortran
      
      export GFORTRAN_LIB="${unstable.gfortran.cc.lib}/lib"
      
      # Runtime linkage helpers
      export DYLD_LIBRARY_PATH="$GFORTRAN_LIB:$DYLD_LIBRARY_PATH"
      export DYLD_FALLBACK_LIBRARY_PATH="$GFORTRAN_LIB:$DYLD_FALLBACK_LIBRARY_PATH"
      
      # Build time linkage
      # Add -L to FFLAGS so the compiler driver sees it too
      export FFLAGS="-L$GFORTRAN_LIB $FFLAGS"
      export NIX_LDFLAGS="-rpath $GFORTRAN_LIB -L$GFORTRAN_LIB $NIX_LDFLAGS"
      export LDFLAGS="-Wl,-rpath,$GFORTRAN_LIB -L$GFORTRAN_LIB $LDFLAGS"
    '';

    preferWheel = true;
    configurePhase = "true"; 
  });

  # GRAFTED RPDS-PY for Darwin
  rpds-py = pkgs.python311Packages.buildPythonPackage {
    pname = "rpds-py";
    version = unstable.python311Packages.rpds-py.version;
    format = "pyproject";
    
    inherit (unstable.python311Packages.rpds-py) src cargoDeps;
    patches = unstable.python311Packages.rpds-py.patches or [];
    cargoPatches = unstable.python311Packages.rpds-py.cargoPatches or [];
    postPatch = unstable.python311Packages.rpds-py.postPatch or "";

    dontCheckRuntimeDeps = true;

    nativeBuildInputs = [
      unstable.cargo 
      unstable.rustc 
      pkgs.rustPlatform.cargoSetupHook
      unstable.maturin
      pkgs.pkg-config
      pkgs.libiconv 
      pkgs.darwin.apple_sdk.frameworks.Security 
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
    ];
    buildInputs = [ pkgs.libiconv ];

    buildPhase = ''
      export CARGO_HOME=$PWD/.cargo
      maturin build --jobs=$NIX_BUILD_CORES --frozen --release --strip --manylinux off
      mkdir -p dist
      mv target/wheels/*.whl dist/
    '';
  };
  
  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
}