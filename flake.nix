{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.3)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

          googleFix = old: {
            postPatch = (old.postPatch or "") + ''
              if [ -f pyproject.toml ]; then
                sed -i '/license = /d' pyproject.toml
                sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
              fi
            '';
          };
        in
        {
          default = p2n.mkPoetryApplication {
            projectDir = ./.;
            python = pkgs.python311;
            # On Mac, we generally prefer wheels. On Linux, we default to source 
            # unless specified otherwise in overrides.
            preferWheels = pkgs.stdenv.isDarwin;
            nativeBuildInputs = [ pkgs.makeWrapper ];

            overrides = p2n.defaultPoetryOverrides.extend (final: prev: {
              # Google Cloud Fixes
              google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
              google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
              google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
              google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
              google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
              google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
              google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
              google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

              # --- HYBRID BUILD STRATEGY ---
              
              # 1. rpds-py
              # Mac: Use Wheel (Fast, works perfectly)
              # Linux: Build from source (Bypasses the "riscv64" crash in poetry2nix)
              rpds-py = prev.rpds-py.overridePythonAttrs (old: {
                preferWheel = pkgs.stdenv.isDarwin;

                # LINUX ONLY: Manually unpack source to fix the "Missing Cargo.lock" error
                prePatch = if pkgs.stdenv.isLinux then ''
                  tar -xf $src --strip-components=1
                '' else "";

                nativeBuildInputs = (old.nativeBuildInputs or []) ++ 
                  (if pkgs.stdenv.isLinux then [ 
                    pkgs.rustPlatform.cargoSetupHook 
                    pkgs.rustPlatform.maturinBuildHook 
                  ] else []);

                # LINUX ONLY: Define Rust dependencies
                # This hash is a placeholder. CI will fail and tell us the real one.
                cargoDeps = if pkgs.stdenv.isLinux then pkgs.rustPlatform.fetchCargoTarball {
                  inherit (final.rpds-py) src;
                  name = "rpds-py-vendor";
                  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                } else null;
              });

              # 2. watchfiles
              # Use wheels everywhere, but patch them on Linux so they run
              watchfiles = prev.watchfiles.overridePythonAttrs (old: {
                preferWheel = true;
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ 
                  (if pkgs.stdenv.isLinux then [ pkgs.autoPatchelfHook ] else [ ]);
              });
            });

            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 \
                --set LC_ALL C.UTF-8 \
                --set LANG C.UTF-8
            '';
          };
        }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [
            self.packages.${system}.default
            nixpkgs.legacyPackages.${system}.gh
            nixpkgs.legacyPackages.${system}.git
            nixpkgs.legacyPackages.${system}.poetry
          ];
        };
      });
    };
}