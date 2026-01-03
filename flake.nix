{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.1.5)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    
    ctx-tool-src = {
      url = "github:andrey-stepantsov/ctx-tool";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, poetry2nix, ctx-tool-src }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };
          
          # --- 1. Custom Tool Build ---
          ctx-tool = pkgs.python3Packages.buildPythonApplication {
            pname = "ctx-tool";
            version = "0.0.1";
            src = ctx-tool-src;
            pyproject = true;
            build-system = [ pkgs.python3Packages.setuptools ];
            dependencies = with pkgs.python3Packages; [ pathspec ];
            doCheck = false;
          };

          # --- 2. The Weaver Script (Fixed) ---
          weave-view = pkgs.writeShellScriptBin "weave-view" ''
            set -e
            if [ "$#" -lt 2 ]; then
              echo "Usage: weave-view <view-name> <src-dir1> [src-dir2...] [--sys <sdk-dir1>...]"
              exit 1
            fi
            
            # FIX: Redundant Naming Check
            INPUT_NAME="$1"; shift
            if [[ "$INPUT_NAME" == view-* ]]; then
                VIEW_NAME="$INPUT_NAME"
            else
                VIEW_NAME="view-$INPUT_NAME"
            fi
            
            echo "🧵 Weaving virtual view: $VIEW_NAME"
            mkdir -p "$VIEW_NAME/_sys"

            JQ_ARGS=""; MODE=0
            declare -a SRC_PATHS
            
            for arg in "$@"; do
              if [ "$arg" == "--sys" ]; then MODE=1; continue; fi
              if [[ "$arg" = /* ]]; then ABS="$arg"; else ABS="$(pwd)/$arg"; fi
              
              if [ $MODE -eq 0 ]; then
                REL=$(dirname "$arg"); mkdir -p "$VIEW_NAME/$REL"
                ln -sf "$ABS" "$VIEW_NAME/$arg"
                SRC_PATHS+=("$ABS")
                if [ -z "$JQ_ARGS" ]; then JQ_ARGS=".file | startswith(\"$ABS\")";
                else JQ_ARGS="$JQ_ARGS or (.file | startswith(\"$ABS\"))"; fi
              else
                ln -sf "$ABS" "$VIEW_NAME/_sys/$(basename "$arg")"
              fi
            done
            
            echo "   [i] Searching for compilation databases..."
            DB_LIST=$(mktemp)
            if [ -f "compile_commands.json" ]; then echo "$(pwd)/compile_commands.json" >> $DB_LIST; fi
            for path in "''${SRC_PATHS[@]}"; do
               find "$path" -maxdepth 3 -name "compile_commands.json" >> $DB_LIST 2>/dev/null || true
            done
            
            UNIQUE_DBS=$(cat $DB_LIST | sort | uniq)
            if [ ! -z "$UNIQUE_DBS" ] && [ ! -z "$JQ_ARGS" ]; then
               COUNT=$(echo "$UNIQUE_DBS" | wc -l)
               echo "   [i] Merging $COUNT compilation databases..."
               echo "$UNIQUE_DBS" | xargs ${pkgs.jq}/bin/jq -s "add | [.[] | select($JQ_ARGS)]" > "$VIEW_NAME/compile_commands.json"
               
               # FIX: Path Safety Check (Docker/Host Mismatch)
               # Detects if we are in Docker but the DB contains MacOS/Host paths
               if grep -q "/Users/" "$VIEW_NAME/compile_commands.json" && [ -f /.dockerenv ]; then
                  echo "   [!] WARNING: Host paths (/Users/...) detected in Docker."
                  echo "       Aider will not find these files unless you rewrite paths or use /data mounting."
               fi
               
               echo "   [✓] Master compile_commands.json created."
            else
               echo "   [!] No compilation databases found (or ignored)."
            fi
            rm -f $DB_LIST
            
            echo "_sys/" > "$VIEW_NAME/.aiderignore"
            if [ -f .aiderignore ]; then cat .aiderignore >> "$VIEW_NAME/.aiderignore"; fi
            echo "✅ View Ready: cd $VIEW_NAME"
          '';

          # --- 3. The CC Toolkit (Context Managers) ---
          
          cc-targets = pkgs.writeShellScriptBin "cc-targets" ''
            if [ -z "$1" ]; then echo "Usage: cc-targets <filename>"; exit 1; fi
            ${pkgs.jq}/bin/jq -r --arg f "$1" '.[] | select(.file | contains($f)) | 
              "--------------------------------------------------",
              "Target: \(.output | split("/")[-2])",
              "  Path: \(.output)",
              "  Arch: \(.arguments | map(select(startswith("-DARCH") or startswith("-DSW_CHIP"))) | join(" "))",
              "Defines: \(.arguments | map(select(startswith("-D"))) | length) flags"' compile_commands.json
          '';

          cc-flags = pkgs.writeShellScriptBin "cc-flags" ''
            if [ -z "$1" ]; then 
              echo "Usage: cc-flags <filename> [regex]"
              exit 1
            fi
            FLAG_REGEX="''${2:-.*}"
            ${pkgs.jq}/bin/jq -r --arg f "$1" --arg re "$FLAG_REGEX" '
              .[] | select(.file | contains($f)) |
              "==================================================",
              "TARGET: \(.output | split("/")[-2])",
              "--------------------------------------------------",
              (.arguments[] | select(test($re)))
            ' compile_commands.json
          '';

          cc-pick = pkgs.writeShellScriptBin "cc-pick" ''
            if [ -z "$2" ]; then
              echo "Usage: cc-pick <filename> <target_keyword>"
              exit 1
            fi
            ${pkgs.jq}/bin/jq --arg f "$1" --arg t "$2" '
              .[] | select(.file | contains($f)) | select(.output | contains($t))
            ' compile_commands.json
          '';

          # --- App Configuration ---
          googleFix = old: {
            postPatch = (old.postPatch or "") + ''
              if [ -f pyproject.toml ]; then
                sed -i '/license = /d' pyproject.toml
                sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
              fi
            '';
          };

          myOverrides = import ./overrides.nix { 
            inherit pkgs googleFix; 
            unstable = pkgs; 
          };

          app = p2n.mkPoetryApplication {
            projectDir = ./.;
            python = pkgs.python311;
            preferWheels = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            overrides = p2n.defaultPoetryOverrides.extend myOverrides;
            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 --set LC_ALL C.UTF-8 --set LANG C.UTF-8
            '';
          };

        in {
          default = app;
          # Export the CC toolkit
          inherit ctx-tool weave-view cc-targets cc-flags cc-pick; 

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "aider-vertex";
            tag = "latest";
            
            extraCommands = ''
              mkdir -p tmp
              chmod 1777 tmp
            '';

            contents = [ 
              app 
              pkgs.cacert pkgs.coreutils 
              pkgs.git pkgs.openssh
              
              # Standard Utils
              pkgs.gnused pkgs.gnugrep pkgs.gawk 
              pkgs.which pkgs.file pkgs.gzip pkgs.gnutar
              
              # Interactive
              pkgs.bashInteractive pkgs.findutils pkgs.procps
              pkgs.less pkgs.ncurses pkgs.vim pkgs.neovim

              # Toolchain
              pkgs.gcc
              pkgs.glibc.dev 
              pkgs.clang
              
              # Toolkit
              pkgs.ripgrep
              pkgs.ast-grep
              pkgs.universal-ctags
              pkgs.bear
              pkgs.jq
              pkgs.clang-tools
              ctx-tool
              weave-view
              cc-targets cc-flags cc-pick # <--- The Suite
            ];

            fakeRootCommands = ''
              mkdir -p /usr/bin
              ln -s ${pkgs.coreutils}/bin/env /usr/bin/env
              ln -sf ${pkgs.bashInteractive}/bin/bash /bin/bash
              
              # --- Mission Pack Support ---
              # Create the mount point and add it to PATH
              mkdir -p /mission/bin
              chmod 755 /mission/bin
              
              mkdir -p /root
              echo 'export PATH=$PATH:/mission/bin' >> /root/.bashrc
              mkdir -p /etc
              echo 'export PATH=$PATH:/mission/bin' >> /etc/bashrc
            '';

            config = {
              Entrypoint = [ "${app}/bin/aider-vertex" ];
              WorkingDir = "/data";
              Volumes = { "/data" = {}; };
              Env = [
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "PYTHONUTF8=1"
                "LC_ALL=C.UTF-8"
                "LANG=C.UTF-8"
                "TERM=xterm-256color"
                "C_INCLUDE_PATH=${pkgs.glibc.dev}/include"
                "CPLUS_INCLUDE_PATH=${pkgs.gcc.cc}/include/c++/${pkgs.gcc.version}"
              ];
            };
          };
        });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ 
            self.packages.${system}.default
            # Utilities
            nixpkgs.legacyPackages.${system}.bashInteractive
            nixpkgs.legacyPackages.${system}.findutils
            nixpkgs.legacyPackages.${system}.jq
            nixpkgs.legacyPackages.${system}.gnused
            nixpkgs.legacyPackages.${system}.gnugrep
            nixpkgs.legacyPackages.${system}.gawk
            nixpkgs.legacyPackages.${system}.ripgrep
            nixpkgs.legacyPackages.${system}.ast-grep
            nixpkgs.legacyPackages.${system}.universal-ctags
            nixpkgs.legacyPackages.${system}.bear
            nixpkgs.legacyPackages.${system}.neovim
            
            # Toolchain
            nixpkgs.legacyPackages.${system}.gcc
            nixpkgs.legacyPackages.${system}.clang
            nixpkgs.legacyPackages.${system}.clang-tools

            # Custom Tools
            self.packages.${system}.ctx-tool
            self.packages.${system}.cc-targets
            self.packages.${system}.cc-flags
            self.packages.${system}.cc-pick
            self.packages.${system}.weave-view
          ];
          
          shellHook = ''
            echo "🚀 Aider-Vertex v1.1.5 Environment Ready"
            echo "   Context Tools:"
            echo "     cc-targets <file>          - List build targets"
            echo "     cc-flags   <file> [regex]  - Inspect flags"
            echo "     cc-pick    <file> <target> - Extract JSON for AI"
          '';
        };
      });
    };
}