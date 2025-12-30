{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.1.1)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    
    # Custom tool source
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

          # --- 2. The Weaver Script (v1.1.1: Multi-DB Support) ---
          weave-view = pkgs.writeShellScriptBin "weave-view" ''
            set -e
            if [ "$#" -lt 2 ]; then
              echo "Usage: weave-view <view-name> <src-dir1> [src-dir2...] [--sys <sdk-dir1>...]"
              exit 1
            fi
            VIEW_NAME="view-$1"; shift
            echo "🧵 Weaving virtual view: $VIEW_NAME"
            mkdir -p "$VIEW_NAME/_sys"

            # 1. Link Files & Build Filter
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
            
            # 2. Aggregated Compilation Database
            # Search for compile_commands.json in root AND all source dirs
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
               echo "   [✓] Master compile_commands.json created."
            else
               echo "   [!] No compilation databases found (or ignored)."
            fi
            rm -f $DB_LIST
            
            echo "_sys/" > "$VIEW_NAME/.aiderignore"
            if [ -f .aiderignore ]; then cat .aiderignore >> "$VIEW_NAME/.aiderignore"; fi
            echo "✅ View Ready: cd $VIEW_NAME"
          '';

          # --- Existing App Configuration ---
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
          inherit ctx-tool weave-view; 

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "aider-vertex";
            tag = "latest";
            
            contents = [ 
              app 
              pkgs.cacert pkgs.coreutils pkgs.bash pkgs.git pkgs.openssh
              pkgs.ripgrep
              pkgs.ast-grep
              pkgs.universal-ctags
              pkgs.bear
              pkgs.jq
              pkgs.clang-tools
              ctx-tool
              weave-view
            ];

            fakeRootCommands = ''
              mkdir -p /tmp
              chmod 1777 /tmp
              mkdir -p /usr/bin
              ln -s ${pkgs.coreutils}/bin/env /usr/bin/env
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
              ];
            };
          };
        });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ 
            self.packages.${system}.default
            nixpkgs.legacyPackages.${system}.ripgrep
            nixpkgs.legacyPackages.${system}.ast-grep
            nixpkgs.legacyPackages.${system}.universal-ctags
            nixpkgs.legacyPackages.${system}.bear
            nixpkgs.legacyPackages.${system}.jq
            nixpkgs.legacyPackages.${system}.clang-tools
            self.packages.${system}.ctx-tool
            self.packages.${system}.weave-view
          ];
          
          shellHook = ''
            echo "🚀 Aider-Vertex Environment Ready"
            echo "   Tools: rg, sg, ctags, bear, jq, ctx, clang-tidy"
            echo "   Helper: weave-view <name> <dirs...>"
          '';
        };
      });
    };
}
