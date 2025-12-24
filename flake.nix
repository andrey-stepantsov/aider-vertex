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

          # 1. Fetch Source
          treeSitterSrc = pkgs.fetchzip {
            url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.23.0.tar.gz";
            hash = "sha256-QNi2u6/jtiMo1dLYoA8Ev1OvZfa8mXCMibSD70J4vVI=";
          };

          # 2. Create a "Corrected" Header Directory
          # Moves lib/src/parser.h -> include/tree_sitter/parser.h
          treeSitterHeaders = pkgs.runCommand "tree-sitter-headers-0.23.0" { src = treeSitterSrc; } ''
            mkdir -p $out/include/tree_sitter
            cp $src/lib/include/tree_sitter/*.h $out/include/tree_sitter/
            cp $src/lib/src/*.h $out/include/tree_sitter/
          '';

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

              # --- FIX: Tree Sitter (Header Compatibility + Build Deps) ---
              
              tree-sitter-c-sharp = prev.tree-sitter-c-sharp.overridePythonAttrs (old: {
                preferWheel = true;
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.setuptools 
                  pkgs.python311Packages.wheel
                ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                preBuild = (old.preBuild or "") + ''
                  export CFLAGS="-I${treeSitterHeaders}/include $CFLAGS"
                '';
              });

              tree-sitter-embedded-template = prev.tree-sitter-embedded-template.overridePythonAttrs (old: {
                preferWheel = true;
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.setuptools 
                  pkgs.python311Packages.wheel
                ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                preBuild = (old.preBuild or "") + ''
                  export CFLAGS="-I${treeSitterHeaders}/include $CFLAGS"
                '';
              });

              tree-sitter-yaml = prev.tree-sitter-yaml.overridePythonAttrs (old: {
                preferWheel = true;
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                  pkgs.python311Packages.setuptools 
                  pkgs.python311Packages.wheel
                ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                preBuild = (old.preBuild or "") + ''
                  export CFLAGS="-I${treeSitterHeaders}/include $CFLAGS"
                '';
              });

              # --- FIX: Linux Build Backend & Metadata Issues ---
              
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
                  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
                  buildInputs = [ pkgs.stdenv.cc.cc.lib ];
                }
              else prev.grpcio.overridePythonAttrs (old: { preferWheel = true; });

              hf-xet = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "hf_xet";
                  version = "1.1.7";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp37";
                    python = "cp37";
                    abi = "abi3";
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    hash = "sha256-bvqvGlqfw6UB0+ceiKa/68ae46cW0OcTqTHIuNkgA48=";
                  };
                }
              else prev.hf-xet.overridePythonAttrs (old: { preferWheel = true; });

              jiter = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "jiter";
                  version = "0.10.0";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    hash = "sha256-TEQOoAOtEJJ6MFIakGLOELVHlZLopw2ifyHutFe0qcU=";
                  };
                }
              else prev.jiter.overridePythonAttrs (old: { preferWheel = true; });

              mslex = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "mslex";
                  version = "1.3.0";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-xwdLNHIBs0ZvwHfFaS+86bX2KmOlH1N6U/u9Au/y7qQ=";
                  };
                }
              else prev.mslex.overridePythonAttrs (old: { preferWheel = true; });

              oslex = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "oslex";
                  version = "0.1.3";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-cay4odQu143dITodOmKLv4N/dYvSmZyR33zleXJGa98=";
                  };
                }
              else prev.oslex.overridePythonAttrs (old: { preferWheel = true; });

              numpy = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "numpy";
                  version = "1.26.4";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    hash = "sha256-Zm2/tuxoliwDOkUJQ97Ykb7S1U5nVeNeWDXWP09pMdU=";
                  };
                  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
                  buildInputs = [ pkgs.gfortran.cc.lib pkgs.zlib ];
                  passthru = { blas = pkgs.openblas; };
                }
              else prev.numpy.overridePythonAttrs (old: { preferWheel = true; });

              scipy = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "scipy";
                  version = "1.15.3";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
                    hash = "sha256-OcucYuRxsbs3UAZuzDo/MFKzd1HHw9/Q/X5IkA7VKYI=";
                  };
                  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
                  buildInputs = [ pkgs.gfortran.cc.lib pkgs.zlib ];
                }
              else prev.scipy.overridePythonAttrs (old: { preferWheel = true; });

              regex = if pkgs.stdenv.isLinux then
                pkgs.python311Packages.buildPythonPackage rec {
                  pname = "regex";
                  version = "2024.11.6";
                  format = "pyproject";
                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-erFZsGPFKgMzyITkZ5+NeoURLuMHj+PZAEst2HVYVRk=";
                  };
                  postPatch = ''
                    if [ -f pyproject.toml ]; then
                      sed -i '/license = /d' pyproject.toml
                      sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                    fi
                  '';
                  nativeBuildInputs = [ pkgs.python311Packages.setuptools pkgs.python311Packages.wheel ];
                }
              else prev.regex.overridePythonAttrs (old: { preferWheel = true; });

              shapely = prev.shapely.overridePythonAttrs (old: {
                preBuild = ''
                  export LD_LIBRARY_PATH=${pkgs.gfortran.cc.lib}/lib:$LD_LIBRARY_PATH
                '';
              });

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
                    # !!! PLACEHOLDER: Run build, copy 'got: sha256-...' hash, and paste here.
                    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
                  };
                }
              else prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
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