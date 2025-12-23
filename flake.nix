{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      # This ensures poetry2nix uses the same nixpkgs as you,
      # preventing version mismatches in the build tools.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      # 1. Define supported architectures for multi-platform claims
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # 2. Helper to generate outputs for each system
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

          # The Google Metadata Fix to handle the Apache-2.0 license naming bug
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

            # THE FIX: Bypass the buggy Linux wheel parser by building from source on Linux.
            # Fast wheels will still be used on your macOS.
            preferWheels = pkgs.stdenv.isDarwin;

            # 3. Add makeWrapper to nativeBuildInputs for the postFixup phase
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

              # Rust-based dependency fixes for cross-platform stability
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

            # 4. Wrap the binary to force UTF-8 support for older Linux terminals (CentOS 7)
            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 \
                --set LC_ALL C.UTF-8 \
                --set LANG C.UTF-8
            '';
          };
        });

      # Optional: Add a development shell for testing
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          # This pulls in everything you need to develop, test, and debug
          packages = [
            # 1. Your actual package (so you can run 'aider-vertex' inside the shell)
            self.packages.${system}.default

            # 2. Essential maintainer tools
            nixpkgs.legacyPackages.${system}.gh # GitHub CLI for checking CI logs
            nixpkgs.legacyPackages.${system}.git # Git for version control
            nixpkgs.legacyPackages.${system}.poetry # In case you need to update poetry.lock
          ];

          # Optional: A nice welcome message when you enter the shell
          shellHook = ''
            echo "--- Aider-Vertex Dev Environment ---"
            echo "Aider: $(aider-vertex --version)"
            echo "GitHub CLI: $(gh --version | head -n 1)"
            echo "------------------------------------"
          '';
        };
      });
    };
}

