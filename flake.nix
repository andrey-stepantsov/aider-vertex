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

            # THE FIX: Use wheels on Mac (stable), source on Linux (bypasses riscv64 bug)
            preferWheels = pkgs.stdenv.isDarwin;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            overrides = p2n.defaultPoetryOverrides.extend (final: prev: {
              # Google SDK Overrides
              google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
              google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
              google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
              google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
              google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
              google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
              google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
              google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

              # Rust dependency stabilization
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
            });

            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 \
                --set LC_ALL C.UTF-8 \
                --set LANG C.UTF-8
            '';
          };
        });

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