{
  description = "Aider-Vertex: Gemini code editing with Vertex AI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "aarch64-darwin"; 
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
    in {
      packages.${system}.default = p2n.mkPoetryApplication {
        projectDir = ./.;
        python = pkgs.python311;
        preferWheels = true;

        overrides = p2n.defaultPoetryOverrides.extend (final: prev: {
          google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
          google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
          google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
          google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
          google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
          google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;

          # Probe for the final rpds-py hash (ALMOST THERE)
          rpds-py = prev.rpds-py.overridePythonAttrs (old: {
            cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
              inherit (old) src;
              name = "rpds-py-vendor";
              hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            };
          });

          # Corrected watchfiles vendor bundle with your verified hash
          watchfiles = pkgs.python311Packages.watchfiles.overridePythonAttrs (old: {
            version = "1.0.0";
            src = pkgs.fetchPypi {
              pname = "watchfiles";
              version = "1.0.0";
              hash = "sha256-N1ZshEyc47XeuWT+GiM3jldedLEUYY0hH72o9Z17Xas=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
              inherit (old) src;
              name = "watchfiles-1.0.0-vendor";
              hash = "sha256-PjS/lr1RcoTopzitvnlLhbowHI98AvJgQSpvucsMJIg=";
            };
          });
        });
      };
    };
}