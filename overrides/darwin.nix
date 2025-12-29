{ pkgs, googleFix, unstable }:
final: prev:
{
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  # macOS can handle unstable tools without dummy packages
  meson = unstable.meson;
  ninja = unstable.ninja;

  # Fix: Inject ninja into pybind11 build inputs
  pybind11 = prev.pybind11.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.ninja ];
  });

  # Fix: Ensure meson-python uses our Unstable meson
  meson-python = prev.meson-python.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.meson ];
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ final.meson ];
  });

  scipy = prev.scipy.overridePythonAttrs (old: {
    nativeBuildInputs = (pkgs.lib.filter 
      (p: (p.pname or "") != "meson" && (p.pname or "") != "ninja") 
      (old.nativeBuildInputs or [])) 
    ++ [
      unstable.meson 
      unstable.ninja
      unstable.pkg-config
      pkgs.gfortran # Use STABLE gfortran
    ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
    
    buildInputs = (old.buildInputs or []) ++ [ pkgs.gfortran.cc.lib ];
    
    # Aggressive Linking to find Stable libgfortran
    preConfigure = (old.preConfigure or "") + ''
      export FC=${pkgs.gfortran}/bin/gfortran
      export DYLD_LIBRARY_PATH="${pkgs.gfortran.cc.lib}/lib:$DYLD_LIBRARY_PATH"
      export DYLD_FALLBACK_LIBRARY_PATH="${pkgs.gfortran.cc.lib}/lib:$DYLD_FALLBACK_LIBRARY_PATH"
      export LDFLAGS="-L${pkgs.gfortran.cc.lib}/lib -Wl,-rpath,${pkgs.gfortran.cc.lib}/lib $LDFLAGS"
    '';

    preferWheel = true;
    configurePhase = "true"; 
  });

  # GRAFTED RPDS-PY for Darwin
  # Strategy: Clean Build + Hybrid Toolchain
  rpds-py = pkgs.python311Packages.buildPythonPackage {
    pname = "rpds-py";
    version = unstable.python311Packages.rpds-py.version;
    format = "pyproject";
    
    inherit (unstable.python311Packages.rpds-py) src cargoDeps;
    patches = unstable.python311Packages.rpds-py.patches or [];
    cargoPatches = unstable.python311Packages.rpds-py.cargoPatches or [];
    postPatch = unstable.python311Packages.rpds-py.postPatch or "";

    # Bypass Metadata 2.4 check
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