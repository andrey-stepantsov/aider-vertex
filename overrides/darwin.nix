{ pkgs, googleFix, unstable }:
final: prev:
{
  # ... (Google overrides same) ...
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
      pkgs.gfortran
    ] ++ [ pkgs.darwin.apple_sdk.frameworks.Accelerate ];
    
    buildInputs = (old.buildInputs or []) ++ [ pkgs.gfortran.cc.lib ];
    
    # FIX: Add both gfortran.cc.lib and gfortran/lib to rpath
    preConfigure = (old.preConfigure or "") + ''
      export FC=${pkgs.gfortran}/bin/gfortran
      export LDFLAGS="-L${pkgs.gfortran.cc.lib}/lib -L${pkgs.gfortran}/lib -Wl,-rpath,${pkgs.gfortran.cc.lib}/lib -Wl,-rpath,${pkgs.gfortran}/lib $LDFLAGS"
    '';

    preferWheel = true;
    configurePhase = "true"; 
  });

  # Use unstable rpds-py on Darwin too, simpler
  rpds-py = unstable.python311Packages.rpds-py;
  
  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
}