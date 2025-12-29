{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # We keep this input just in case poetry2nix needs it, 
    # but we won't use it for the main build.
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
          # FIX: Use stable 24.11 for BOTH Linux and macOS to ensure SDK stability
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

          myOverrides = import ./overrides.nix { 
            inherit pkgs googleFix; 
            # Pass stable as "unstable" to match the overrides signature
            unstable = pkgs; 
          };
        in {
          default = p2n.mkPoetryApplication {
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
        });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ self.packages.${system}.default ];
        };
      });
    };
}