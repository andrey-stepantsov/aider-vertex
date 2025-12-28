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
  # Clean build strategy for macOS as well
  rpds-py = pkgs.python311Packages.buildPythonPackage {
    pname = "rpds-py";
    version = unstable.python311Packages.rpds-py.version;
    format = "pyproject";
    
    inherit (unstable.python311Packages.rpds-py) src cargoDeps;
    patches = unstable.python311Packages.rpds-py.patches or [];
    cargoPatches = unstable.python311Packages.rpds-py.cargoPatches or [];
    postPatch = unstable.python311Packages.rpds-py.postPatch or "";

    nativeBuildInputs = [
      pkgs.cargo 
      pkgs.rustc 
      pkgs.rustPlatform.cargoSetupHook 
      pkgs.rustPlatform.maturinBuildHook 
      pkgs.pkg-config
      pkgs.libiconv 
      pkgs.darwin.apple_sdk.frameworks.Security 
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
    ];
    buildInputs = [ pkgs.libiconv ];
  };
  
  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
}