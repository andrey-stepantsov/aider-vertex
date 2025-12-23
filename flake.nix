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
              # --- Google Cloud Fixes ---
              google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
              google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
              google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
              google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
              google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
              google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
              google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
              google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

              # --- FIX: Hybrid Build Strategy ---
              
              # 1. rpds-py
              # Linux: Manual Source Build (Bypasses the "riscv64" crash in poetry2nix evaluation)
              # Mac: Use default poetry2nix generation (Wheels)
              rpds-py = if pkgs.stdenv.isLinux then 
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "rpds_py";
                  version = "0.22.3";
                  format = "pyproject";
                  
                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
                  };

                  nativeBuildInputs = with pkgs; [
                    rustPlatform.cargoSetupHook
                    rustPlatform.maturinBuildHook
                  ];

                  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                    inherit src;
                    name = "${pname}-${version}";
                    # PLACEHOLDER: The CI failure will tell us the real hash to put here
                    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                  };
                }
              else 
                prev.rpds-py.overridePythonAttrs (old: {
                  preferWheel = true;
                });

              # 2. watchfiles
              # Linux: Manual Source Build (Bypasses "missing version 1.1.0" error in poetry2nix)
              # Mac: Use default poetry2nix generation (Wheels)
              watchfiles = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "watchfiles";
                  version = "1.1.0";
                  format = "pyproject";

                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-o7I9QxappJ+XvM0uXEtM5O9b/iO/M06PT+QvSIj7Xns=";
                  };

                  nativeBuildInputs = with pkgs; [
                    rustPlatform.cargoSetupHook
                    rustPlatform.maturinBuildHook
                    # Linux needs autoPatchelfHook if we were using wheels, 
                    # but for source build it handles linking itself.
                  ];

                  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                    inherit src;
                    name = "${pname}-${version}";
                    # PLACEHOLDER: The CI failure will tell us the real hash to put here
                    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                  };
                }
              else
                prev.watchfiles.overridePythonAttrs (old: {
                  preferWheel = true;
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