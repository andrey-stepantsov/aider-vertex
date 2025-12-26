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

  # --- Replaced Packages to Bypass poetry2nix riscv64 crash on Linux ---
  # The crash happens when poetry2nix evaluates wheels with 'riscv64' tags on Linux.
  # We must completely replace the derivation on Linux to avoid triggering the crashing logic in 'prev'.

  rpds-py = if pkgs.stdenv.isLinux then
    pkgs.python311Packages.buildPythonPackage rec {
      pname = "rpds_py";
      version = "0.22.3";
      format = "pyproject";

      src = pkgs.fetchPypi {
        inherit pname version;
        hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
      };

      cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
        inherit src;
        name = "rpds-py-vendor";
        hash = "sha256-0YwuSSV2BuD3f2tHDLRN12umkfSaJGIX9pw4/rf20V8=";
      };

      nativeBuildInputs = with pkgs; [
        rustPlatform.cargoSetupHook
        rustPlatform.maturinBuildHook
      ];
    }
  else
    prev.rpds-py.overridePythonAttrs (old: {
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

  watchfiles = if pkgs.stdenv.isLinux then
    pkgs.python311Packages.watchfiles
  else
    prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });

  # --- Place Linux Fixes Below This Line ---
}
