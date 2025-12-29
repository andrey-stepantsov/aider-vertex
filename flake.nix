{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, poetry2nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          # Define both package sets
          stablePkgs = nixpkgs.legacyPackages.${system};
          unstablePkgs = nixpkgs-unstable.legacyPackages.${system};
          
          # STRATEGIC SPLIT:
          # On Linux: Use Stable packages + Stable Python (3.11.10).
          # On macOS: Use Unstable packages + Unstable Python (3.11.14) to match the grafted SciPy binary.
          pkgs = if stablePkgs.stdenv.isDarwin then unstablePkgs else stablePkgs;
          
          # We still need access to 'unstable' for overrides, but now 'pkgs' itself might BE unstable on Mac.
          # To avoid confusion in overrides, we pass 'unstablePkgs' explicitly as 'unstable'.
          
          # Initialize poetry2nix with the CHOSEN package set (Stable on Linux, Unstable on Mac)
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
            unstable = unstablePkgs; 
          };
        in {
          default = p2n.mkPoetryApplication {
            projectDir = ./.;
            python = pkgs.python311; # This will be 3.11.10 on Linux, 3.11.14 on Mac
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