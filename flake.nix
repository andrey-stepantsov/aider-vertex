{
  description = "Aider-Vertex: Gemini code editing with Vertex AI (v1.0.3-modular)";

  inputs = {
    # Downgrade to 24.05 to match the frozen state of poetry2nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    
    # ADD: Unstable for modern Rust toolchains (fixes rpds-py lockfile v4 errors)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, poetry2nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # ADD: Access to unstable packages
          unstable = nixpkgs-unstable.legacyPackages.${system};
          
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
            preferWheels = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];

            overrides = [
              p2n.defaultPoetryOverrides
              # CHANGE: Pass 'unstable' to overrides
              (import ./overrides.nix { inherit pkgs googleFix unstable; })
            ];

            postFixup = ''
              wrapProgram $out/bin/aider-vertex \
                --set PYTHONUTF8 1 \
                --set LC_ALL C.UTF-8 \
                --set LANG C.UTF-8
            '';
          };
        });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [
            self.packages.${system}.default
            nixpkgs.legacyPackages.${system}.gh
          ];
        };
      });
    };
}