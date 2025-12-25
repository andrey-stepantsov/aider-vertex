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

          # --- Header Management ---
          treeSitter23Src = pkgs.fetchzip {
            url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.23.0.tar.gz";
            hash = "sha256-QNi2u6/jtiMo1dLYoA8Ev1OvZfa8mXCMibSD70J4vVI=";
          };
          treeSitter23Headers = pkgs.runCommand "tree-sitter-headers-0.23" { src = treeSitter23Src; } ''
            mkdir -p $out/include/tree_sitter
            cp $src/lib/include/tree_sitter/*.h $out/include/tree_sitter/
            cp $src/lib/src/*.h $out/include/tree_sitter/
          '';

          # Add 0.22 headers for older grammars (fixes TSMapSlice error)
          treeSitter22Src = pkgs.fetchzip {
            url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.22.6.tar.gz";
            hash = "sha256-QtC+L4o400+2vC67v8W45c9qY8S6VqmiGrXFp049bNY=";
          };
          treeSitter22Headers = pkgs.runCommand "tree-sitter-headers-0.22" { src = treeSitter22Src; } ''
            mkdir -p $out/include/tree_sitter
            cp $src/lib/include/tree_sitter/*.h $out/include/tree_sitter/
            cp $src/lib/src/*.h $out/include/tree_sitter/
          '';

          # Standard Google Cloud package fix
          googleFix = old: {
            # Ensure setuptools is present for all Google packages
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
            postPatch = (old.postPatch or "") + ''
              if [ -f pyproject.toml ]; then
                sed -i '/license = /d' pyproject.toml
                sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                sed -i '/license-files/d' pyproject.toml
              fi
            '';
          };
        in
        {
          default = p2n.mkPoetryApplication {
            projectDir = ./.;
            python = pkgs.python311;
            preferWheels = false; 
            nativeBuildInputs = [ pkgs.makeWrapper ];

            overrides = p2n.defaultPoetryOverrides.extend (final: prev: {
              # --- Google Cloud & Metadata Fixes ---
              google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
              google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
              google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
              google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
              google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
              google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
              google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
              google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;
              typing-extensions = prev.typing-extensions.overridePythonAttrs googleFix;
              
              # Fix anyio metadata error
              anyio = prev.anyio.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Fix attrs metadata error
              attrs = prev.attrs.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                  fi
                '';
              });

              # Fix jsonschema metadata error
              jsonschema = prev.jsonschema.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                  fi
                '';
              });

              # Fix referencing metadata error
              referencing = prev.referencing.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                  fi
                '';
              });

              # Fix jsonschema-specifications metadata error
              jsonschema-specifications = prev.jsonschema-specifications.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                  fi
                '';
              });

              # Fix iniconfig metadata error
              iniconfig = prev.iniconfig.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Fix frozenlist metadata error
              frozenlist = prev.frozenlist.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.hatchling 
                  pkgs.python311Packages.hatch-vcs 
                ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                  fi
                '';
              });

              # Fix Pillow metadata
              pillow = prev.pillow.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.flit-core ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "HPND"}' pyproject.toml
                  fi
                '';
              });

              # Fix typing-inspection metadata
              typing-inspection = prev.typing-inspection.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.hatchling ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                  fi
                '';
              });

              # Fix urllib3 metadata error
              urllib3 = prev.urllib3.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.hatchling ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Fix zipp metadata error
              zipp = prev.zipp.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools-scm ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Fix tree-sitter-language-pack metadata
              tree-sitter-language-pack = prev.tree-sitter-language-pack.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/license = /d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Fix posthog metadata error
              posthog = prev.posthog.overridePythonAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                   if [ -f pyproject.toml ]; then
                    sed -i '/license-files/d' pyproject.toml
                    sed -i '/license = /d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "MIT"}' pyproject.toml
                  fi
                '';
              });

              # Pre-emptively fix multidict
              multidict = prev.multidict.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                  fi
                '';
              });

              # Pre-emptively fix yarl
              yarl = prev.yarl.overridePythonAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
                postPatch = (old.postPatch or "") + ''
                  if [ -f pyproject.toml ]; then
                    sed -i '/^license/d' pyproject.toml
                    sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                  fi
                '';
              });

              # FIX: Use Wheels for tiktoken on ALL systems
              tiktoken = if pkgs.stdenv.isLinux then prev.tiktoken.overridePythonAttrs (old: {
                src = pkgs.fetchFromGitHub {
                  owner = "openai";
                  repo = "tiktoken";
                  rev = "0.10.0";
                  hash = "sha256-V/61n/oV25L2ZfD9uv6WqT9l4u402yM5p7Cg8L11uXk=";
                };
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.setuptools
                  pkgs.python311Packages.setuptools-rust
                  pkgs.cargo
                  pkgs.rustc
                  pkgs.rustPlatform.cargoSetupHook
                ];
                cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                  src = pkgs.fetchFromGitHub {
                    owner = "openai";
                    repo = "tiktoken";
                    rev = "0.10.0";
                    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                  };
                  name = "${old.pname}-${old.version}";
                  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                };
              }) else pkgs.python311Packages.buildPythonPackage rec {
                pname = "tiktoken";
                version = "0.10.0";
                format = "wheel";
                src = pkgs.fetchPypi {
                  inherit pname version format;
                  dist = "cp311";
                  python = "cp311";
                  abi = "cp311";
                  platform = "macosx_12_0_arm64"; # Try macOS 12+ wheel
                  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder
                };
              };
            });

            postFixup = ''
              # Ensure the binary is renamed BEFORE wrapping
              if [ -f $out/bin/aider ]; then
                mv $out/bin/aider $out/bin/aider-vertex
              fi

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
