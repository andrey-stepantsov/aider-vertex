{ pkgs, googleFix }:
final: prev: {
  # --- Google Cloud Fixes (Keep these) ---
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  # --- Existing Working Fixes ---
  rpds-py = prev.rpds-py.overridePythonAttrs (old: {
    preferWheel = false; 
    src = pkgs.fetchPypi {
      pname = "rpds_py";
      version = "0.22.3";
      hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
    };
    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
      inherit (final.rpds-py) src;
      name = "rpds-py-vendor";
      hash = "sha256-0YwuSSV2BuD3f2tHDLRN12umkfSaJGIX9pw4/rf20V8=";
    };
  });

  watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });

  # --- Place Linux Fixes Below This Line ---
  # (Aider will add linux-specific overrides here)
}