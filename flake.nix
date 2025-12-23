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

              # --- FIX: Broken Metadata / Build Backends ---
              
              aiohappyeyeballs = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "aiohappyeyeballs";
                  version = "2.6.1";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-80m6j0t1yyXJnFwthOmX5IUgTSkCqVl4ArA3HwkzH7g=";
                  };
                }
              else prev.aiohappyeyeballs.overridePythonAttrs (old: { preferWheel = true; });

              click = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "click";
                  version = "8.2.1";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-YaMmW5FOhQuFMX0LMQnH+M01pnD5Y4ZgBdbvHVF1oSs=";
                  };
                }
              else prev.click.overridePythonAttrs (old: { preferWheel = true; });

              docstring-parser = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "docstring_parser";
                  version = "0.17.0";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-zyVpq9I9zoCZswD5tPqBkelYLdpzH9Uz2vVMRVFlhwg=";
                  };
                }
              else prev.docstring-parser.overridePythonAttrs (old: { preferWheel = true; });

              grpcio = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "grpcio";
                  version = "1.74.0"; 
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    hash = "sha256-yY4LdDSn+k4+Y/JQRW6u9SSZ+6WuZhxYzFtUd9EecYI=";
                  };
                }
              else prev.grpcio.overridePythonAttrs (old: { preferWheel = true; });

              # Force ABI3 wheel for hf-xet (Rust package)
              hf-xet = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "hf_xet";
                  version = "1.1.7";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp37";  # Changed to cp37 (abi3)
                    python = "cp37"; # Changed to cp37 (abi3)
                    abi = "abi3";    # Changed to abi3
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    # Placeholder GGGG: CI will fail here first
                    hash = "sha256-GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG=";
                  };
                }
              else prev.hf-xet.overridePythonAttrs (old: { preferWheel = true; });

              # --- FIX: Hybrid Build Strategy (Rust Packages) ---
              
              rpds-py = if pkgs.stdenv.isLinux then 
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "rpds_py";
                  version = "0.22.3";
                  format = "pyproject";
                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
                  };
                  nativeBuildInputs = with pkgs; [ rustPlatform.cargoSetupHook rustPlatform.maturinBuildHook ];
                  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                    inherit src;
                    name = "${pname}-${version}";
                    hash = "sha256-zpmgLLsNA3OzuaSBWoAZuA5nMg9mXWbY5qILE+7hucs=";
                  };
                }
              else prev.rpds-py.overridePythonAttrs (old: { preferWheel = true; });

              watchfiles = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "watchfiles";
                  version = "1.1.0";
                  format = "pyproject";
                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-aT7X7HLL/O45npLIlTYrbmbWPaxrkeLBGuA9ENUD5XU=";
                  };
                  nativeBuildInputs = with pkgs; [ rustPlatform.cargoSetupHook rustPlatform.maturinBuildHook ];
                  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                    inherit src;
                    name = "${pname}-${version}";
                    # Placeholder BBBB: Still waiting for this!
                    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
                  };
                }
              else prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
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