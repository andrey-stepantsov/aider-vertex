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
          # Use the source from nixpkgs' tree-sitter to avoid managing hashes manually
          # This assumes nixpkgs 24.11 has a recent enough tree-sitter (v0.24+)
          treeSitter24Src = pkgs.tree-sitter.src;
          treeSitter24Headers = pkgs.runCommand "tree-sitter-headers-0.24" { src = treeSitter24Src; } ''
            mkdir -p $out/include/tree_sitter
            cp $src/lib/include/tree_sitter/*.h $out/include/tree_sitter/
            cp $src/lib/src/*.h $out/include/tree_sitter/
          '';

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
            hash = "sha256-jBCKgDlvXwA7Z4GDBJ+aZc52zC+om30DtsZJuHado1s=";
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

            overrides = [
              # 1. Spoof versions to bypass poetry2nix default overrides crash
              # We set versions to ones that poetry2nix likely knows about, so it doesn't crash looking up hashes.
              # Our manual overrides (step 3) will overwrite these packages anyway.
              (final: prev: {
                watchfiles = prev.watchfiles.overridePythonAttrs (old: { version = "0.19.0"; });
                rpds-py = prev.rpds-py.overridePythonAttrs (old: { version = "0.18.0"; }); 
              })

              # 2. The Defaults (now safe because they see "known" versions)
              p2n.defaultPoetryOverrides

              # 3. My Manual Overrides (restoring sanity and correct versions)
              (final: prev: {
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
                frozenlist = if pkgs.stdenv.isLinux then prev.frozenlist.overridePythonAttrs (old: {
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
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "frozenlist";
                  version = prev.frozenlist.version;
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64";
                    hash = "sha256-0000000000000000000000000000000000000000000=";
                  };
                };

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
                multidict = if pkgs.stdenv.isLinux then prev.multidict.overridePythonAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
                  postPatch = (old.postPatch or "") + ''
                    if [ -f pyproject.toml ]; then
                      sed -i '/^license/d' pyproject.toml
                      sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                    fi
                  '';
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "multidict";
                  version = prev.multidict.version;
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64";
                    hash = "sha256-v5vR/V7sAUlODy6ORGp0qF1eSa+2PXWpk05KVCPboh0=";
                  };
                };

                # Pre-emptively fix yarl
                yarl = if pkgs.stdenv.isLinux then prev.yarl.overridePythonAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.python311Packages.setuptools ];
                  postPatch = (old.postPatch or "") + ''
                    if [ -f pyproject.toml ]; then
                      sed -i '/^license/d' pyproject.toml
                      sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
                    fi
                  '';
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "yarl";
                  version = prev.yarl.version;
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64";
                    hash = "sha256-0000000000000000000000000000000000000000000=";
                  };
                };

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
                    platform = "macosx_11_0_arm64"; # Corrected to 11_0
                    hash = "sha256-9kHQc1BZtIJSxECdZUa2pi7etMTkgwZJnbEbvkA7hy8=";
                  };
                  propagatedBuildInputs = [ final.regex final.requests ];
                };

                # --- FIX: Tree Sitter Builds ---
                tree-sitter-c-sharp = prev.tree-sitter-c-sharp.overridePythonAttrs (old: {
                  preferWheel = true;
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                    pkgs.python311Packages.setuptools 
                    pkgs.python311Packages.wheel
                  ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                  preBuild = (old.preBuild or "") + ''
                    mkdir -p src/tree_sitter
                    cp ${treeSitter23Headers}/include/tree_sitter/*.h src/tree_sitter/
                  '';
                });

                tree-sitter-embedded-template = prev.tree-sitter-embedded-template.overridePythonAttrs (old: {
                  preferWheel = true;
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                    pkgs.python311Packages.setuptools 
                    pkgs.python311Packages.wheel
                  ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                  preBuild = (old.preBuild or "") + ''
                    mkdir -p src/tree_sitter
                    cp ${treeSitter23Headers}/include/tree_sitter/*.h src/tree_sitter/
                  '';
                });

                # FIX: Update tree-sitter-yaml source from GitHub and use compatible headers
                tree-sitter-yaml = prev.tree-sitter-yaml.overridePythonAttrs (old: {
                  version = "0.7.1";
                  preferWheel = false;
                  src = pkgs.fetchFromGitHub {
                     owner = "tree-sitter";
                     repo = "tree-sitter-yaml";
                     rev = "v0.7.1";
                     # Placeholder hash to be updated
                     hash = "sha256-0000000000000000000000000000000000000000000=";
                  };
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                    pkgs.python311Packages.setuptools 
                    pkgs.python311Packages.wheel
                  ] ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ]);
                  preBuild = (old.preBuild or "") + ''
                    mkdir -p src/tree_sitter
                    cp ${treeSitter24Headers}/include/tree_sitter/*.h src/tree_sitter/
                  '';
                });

                # --- FIX: Linux Build Backend & Metadata Issues ---
                aiohappyeyeballs = pkgs.python311Packages.buildPythonPackage rec {
                  pname = "aiohappyeyeballs";
                  version = "2.6.1";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-80m6j0t1yyXJnFwthOmX5IUgTSkCqVl4ArA3HwkzH7g=";
                  };
                };

                click = pkgs.python311Packages.buildPythonPackage rec {
                  pname = "click";
                  version = "8.2.1";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-YaMmW5FOhQuFMX0LMQnH+M01pnD5Y4ZgBdbvHVF1oSs=";
                  };
                };

                docstring-parser = pkgs.python311Packages.buildPythonPackage rec {
                  pname = "docstring_parser";
                  version = "0.17.0";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-zyVpq9I9zoCZswD5tPqBkelYLdpzH9Uz2vVMRVFlhwg=";
                  };
                };

                mslex = pkgs.python311Packages.buildPythonPackage rec {
                  pname = "mslex";
                  version = "1.3.0";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-xwdLNHIBs0ZvwHfFaS+86bX2KmOlH1N6U/u9Au/y7qQ=";
                  };
                };

                oslex = pkgs.python311Packages.buildPythonPackage rec {
                  pname = "oslex";
                  version = "0.1.3";
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "py3";
                    python = "py3";
                    hash = "sha256-cay4odQu143dITodOmKLv4N/dYvSmZyR33zleXJGa98=";
                  };
                };

                # --- Platform Specific or C-Extension Packages ---
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

                # FIX: Force wheel on Darwin for hf-xet
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
                else 
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "hf_xet";
                    version = "1.1.7";
                    format = "wheel";
                    src = pkgs.fetchPypi {
                      inherit pname version format;
                      dist = "cp37";
                      python = "cp37";
                      abi = "abi3";
                      platform = "macosx_11_0_arm64";
                      hash = "sha256-sQn0wR4BwFf8ggBMnlHmzf4ssjBjdkSt5AxZlzkGey4=";
                    };
                  };

                # FIX: Force wheel on Darwin for jiter
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
                else 
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "jiter";
                    version = "0.10.0";
                    format = "wheel";
                    src = pkgs.fetchPypi {
                       inherit pname version format;
                       dist = "cp311";
                       python = "cp311";
                       abi = "cp311";
                       platform = "macosx_11_0_arm64";
                       hash = "sha256-VYzH5E/Y5QeiNr7moC+hcZm6dSh0QAoMps1uIZbNt9w=";
                    };
                  };

                # FIX: Force wheel on Darwin for numpy to avoid compilation
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
                else 
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "numpy";
                    version = "1.26.4";
                    format = "wheel";
                    src = pkgs.fetchPypi {
                      inherit pname version format;
                      dist = "cp311";
                      python = "cp311";
                      abi = "cp311";
                      platform = "macosx_11_0_arm64";
                      hash = "sha256-7di1/kfasJEXbSG7beVorN2QbRiHpFhKFampah3KBu8=";
                    };
                  };

                # FIX: Force wheel on Darwin for scipy to avoid compilation
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
                else 
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "scipy";
                    version = "1.15.3"; 
                    format = "wheel";
                    src = pkgs.fetchPypi {
                      inherit pname version format;
                      dist = "cp311";
                      python = "cp311";
                      abi = "cp311";
                      platform = "macosx_12_0_arm64"; # SciPy often targets macOS 12+ on ARM
                      # Placeholder hash to be filled in by user
                      hash = "sha256-NHFuKB8YGgI0Hd6q1YQgW9L9PCQgY700I9YawlnKfro=";
                    };
                  };

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
                else 
                  # FIX: Force wheel on Darwin for regex to avoid compilation/metadata issues
                  pkgs.python311Packages.buildPythonPackage rec {
                    inherit (prev.regex) pname version;
                    format = "wheel";
                    src = pkgs.fetchPypi {
                      inherit pname version format;
                      dist = "cp311";
                      python = "cp311";
                      abi = "cp311";
                      platform = "macosx_11_0_arm64";
                      hash = "sha256-lruuTGFnJvRmH+e8rVlS4Q0l08Ud3DiBidiGT7wbPGg=";
                    };
                  };

                shapely = if pkgs.stdenv.isLinux then prev.shapely.overridePythonAttrs (old: {
                  preBuild = ''
                    export LD_LIBRARY_PATH=${pkgs.gfortran.cc.lib}/lib:$LD_LIBRARY_PATH
                  '';
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "shapely";
                  version = prev.shapely.version;
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64";
                    hash = "sha256-FqnHIrp3TPULXUVBJCtMzgWq/USgFSkMgrqKFpMf9j0=";
                  };
                };

                # --- FIX: Hybrid Build Strategy (Rust Packages) ---
                # FIX: Force wheel on Darwin for pydantic-core
                pydantic-core = if pkgs.stdenv.isLinux then prev.pydantic-core.overridePythonAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                    pkgs.rustPlatform.maturinBuildHook 
                    pkgs.python311Packages.maturin
                  ];
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "pydantic_core";
                  version = prev.pydantic-core.version;
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64";
                    hash = "sha256-55nAUN84pjnbdYxhfsdx/Y+3pfjqqksnsQHyZrIWokY=";
                  };
                };

                rpds-py = if pkgs.stdenv.isLinux then 
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "rpds_py";
                    version = "0.27.0"; 
                    format = "pyproject";
                    src = pkgs.fetchPypi {
                      inherit pname version;
                      hash = "sha256-5+h3rB2yqJ0b9l5c9v8k1h4j2l5+3f4g6h8j9k0l1m2n3o="; # Placeholder
                    };
                    nativeBuildInputs = with pkgs; [ rustPlatform.cargoSetupHook rustPlatform.maturinBuildHook ];
                    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                      inherit src;
                      name = "${pname}-${version}";
                      hash = "sha256-placeholder-for-rpds="; 
                    };
                  }
                else 
                  # Pure wheel override for Darwin to bypass prev logic
                  pkgs.python311Packages.buildPythonPackage rec {
                     pname = "rpds_py";
                     version = "0.27.0";
                     format = "wheel";
                     src = pkgs.fetchPypi {
                       inherit pname version format;
                       dist = "cp311";
                       python = "cp311";
                       abi = "cp311";
                       platform = "macosx_11_0_arm64"; # Specific to aarch64-darwin
                       hash = "sha256-fshZlPlqWM9+0ojKo0S3/jH9HVA73xPXMx6tX3CrYNU="; # Corrected Hash
                     };
                  };

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
                    propagatedBuildInputs = [ final.anyio ];
                    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                      inherit src;
                      name = "${pname}-${version}";
                      hash = "sha256-IoEWdK8DZrq9fPdl6b50jacuJb47rWYF+Pro/mgP67E=";
                    };
                  }
                else 
                  # Pure wheel override for Darwin to bypass prev logic
                  pkgs.python311Packages.buildPythonPackage rec {
                    pname = "watchfiles";
                    version = "1.1.0";
                    format = "wheel";
                    src = pkgs.fetchPypi {
                      inherit pname version format;
                      dist = "cp311";
                      python = "cp311";
                      abi = "cp311";
                      platform = "macosx_11_0_arm64"; # Specific to aarch64-darwin
                      hash = "sha256-0000000000000000000000000000000000000000000=";
                    };
                    propagatedBuildInputs = [ final.anyio ];
                  };

                # FIX: Build tokenizers from source on Linux, Force Wheel on Darwin
                tokenizers = if pkgs.stdenv.isLinux then prev.tokenizers.overridePythonAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
                    pkgs.rustPlatform.maturinBuildHook 
                    pkgs.python311Packages.maturin
                  ];
                }) else pkgs.python311Packages.buildPythonPackage rec {
                  pname = "tokenizers";
                  version = "0.19.1"; # Corrected to a version available on PyPI
                  format = "wheel";
                  src = pkgs.fetchPypi {
                    inherit pname version format;
                    dist = "cp311";
                    python = "cp311";
                    abi = "cp311";
                    platform = "macosx_11_0_arm64"; # Platform for version 0.19.1
                    hash = "sha256-3fZy7XGbTtgrUUmRAPVBfX2fb7BaZeIyJJJo813l7RQ=";
                  };
                };
              })
            ];

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
