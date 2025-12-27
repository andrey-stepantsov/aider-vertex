{ pkgs, googleFix, unstable }:
final: prev:
let
  # ---------------------------------------------------------------------------
  # 1. COMMON: Applies to both macOS and Linux
  # ---------------------------------------------------------------------------
  common = {
    google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
    google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
    google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
    google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
    google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
    google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
    google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
    google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

    rpds-py = prev.rpds-py.overridePythonAttrs (old: 
      let
        # Fetch dependencies using the unstable fetcher (required for v4 lockfiles)
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

        # We manually configure cargo below, so we don't rely on the automatic hook validation
        cargoDeps = rustDeps;
        
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          # STABLE maturin hook (prevents 'concatTo' shell errors)
          pkgs.rustPlatform.maturinBuildHook
          
          # NOTE: We intentionally OMIT cargoSetupHook here to avoid the strict
          # validation error about the lockfile location. We configure it manually in preConfigure.
          
          # UNSTABLE toolchain (understands v4 Cargo.lock)
          unstable.cargo
          unstable.rustc
        ];

        # Force hooks to use the unstable binaries
        CARGO = "${unstable.cargo}/bin/cargo";
        RUSTC = "${unstable.rustc}/bin/rustc";

        # FIX: Manually unpack because poetry2nix incorrectly assumes this is a wheel
        unpackPhase = ''
          echo ">>> Manual UnpackPhase: Extracting $src"
          tar -xf $src
          srcDir=$(find . -maxdepth 1 -type d -name "rpds_py*" -o -name "rpds-py*" | head -n 1)
          if [ -z "$srcDir" ]; then echo "❌ Error: Could not find extracted directory"; exit 1; fi
          echo ">>> Setting sourceRoot to $srcDir"
          export sourceRoot="$srcDir"
        '';

        # FIX: Manually configure Cargo to use the vendored dependencies.
        # This replaces the work usually done by cargoSetupHook, bypassing the file check failure.
        preConfigure = ''
          echo ">>> Manual Cargo Config: Pointing to vendor directory: ${rustDeps}"
          mkdir -p .cargo
          cat > .cargo/config.toml <<EOF
          [source.crates-io]
          replace-with = "vendored-sources"

          [source.vendored-sources]
          directory = "${rustDeps}"
          EOF
          
          # Ensure Cargo uses this config
          export CARGO_HOME=$(pwd)/.cargo
        '';

        # Disable poetry2nix's default wheel unpack logic
        wheelUnpackPhase = "true"; 
    });

    watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
  };

  # ---------------------------------------------------------------------------
  # 2. MACOS: Only applied on Darwin (Manual Wheels)
  # ---------------------------------------------------------------------------
  darwin = if pkgs.stdenv.isDarwin then {} else {};

  # ---------------------------------------------------------------------------
  # 3. LINUX: Only applied on Linux (Source builds & Manylinux fixes)
  # ---------------------------------------------------------------------------
  linux = if pkgs.stdenv.isLinux then {
    watchfiles = prev.watchfiles.overridePythonAttrs (old: {
      preferWheel = true;
      propagatedBuildInputs = (pkgs.lib.filter (p: p.pname != "anyio") old.propagatedBuildInputs) ++ [ final.anyio ];
    });
  } else {};

in
  common // darwin // linux