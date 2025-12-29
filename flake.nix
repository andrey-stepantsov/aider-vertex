{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, poetry2nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };
          
          # Fix for Google packages that sometimes have license issues in metadata
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
            # Ensure Python runs in UTF-8 mode to avoid encoding crashes
            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 --set LC_ALL C.UTF-8 --set LANG C.UTF-8
            '';
          };

        in {
          default = app;

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "aider-vertex";
            tag = "latest";
            
            contents = [ 
              app 
              pkgs.cacert    # Required for HTTPS (Vertex AI API calls)
              pkgs.coreutils # Basic tools (mkdir, ls, etc.)
              pkgs.bash      # Shell for debugging
              pkgs.git       # Required by Aider for repo management
              pkgs.openssh   # Required if using git over SSH
            ];

            fakeRootCommands = ''
              mkdir -p /tmp
              chmod 1777 /tmp
              mkdir -p /usr/bin
              ln -s ${pkgs.coreutils}/bin/env /usr/bin/env
            '';

            config = {
              # Entrypoint ensures arguments are appended to the command
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
          packages = [ self.packages.${system}.default ];
        };
      });
    };
}