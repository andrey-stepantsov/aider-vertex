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

  # We don't need dummy packages on macOS
  meson = unstable.meson;
  ninja = unstable.ninja;

  # Backport Scipy from Unstable (fixes linking issues)
  scipy = (unstable.python311Packages.scipy.override {
    python3 = pkgs.python311;
  }).overridePythonAttrs (old: {
    # Nixpkgs unstable scipy already handles gfortran correctly. 
    # We just ensure it uses our python.
  });

  # Backport RPDS-PY from Unstable
  rpds-py = unstable.python311Packages.rpds-py.override {
    python3 = pkgs.python311;
  };
  
  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
}