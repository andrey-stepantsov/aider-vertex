{
  description = "Aider-Vertex: Gemini code editing with Vertex AI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "aarch64-darwin"; 
      pkgs = nixpkgs.legacyPackages.${system};
      p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };
      
      # REVISED: Injecting the license as a proper PEP 621 table
      googleFix = old: {
        postPatch = (old.postPatch or "") + ''
          if [ -f pyproject.toml ]; then
            # Remove any existing problematic license declarations
            sed -i '/license = /d' pyproject.toml
            # Inject the license table under the [project] section
            sed -i '/\[project\]/a license = {text = "Apache-2.0"}' pyproject.toml
          fi
        '';
      };
    in {
      packages.${system}.default = p2n.mkPoetryApplication {
        projectDir = ./.;
        python = pkgs.python311;
        preferWheels = true;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        overrides = p2n.defaultPoetryOverrides.extend (final: prev: {
          google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
          google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
          google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
          google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
          google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
          google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
          google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
          google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

          rpds-py = prev.rpds-py.overridePythonAttrs (old: {
            preferWheel = false; 
            src = pkgs.fetchPypi {
              pname = "rpds_py";
              version = "0.22.3";
              hash = "sha256-4y/uirRdPC222hmlMjvDNiI3yLZTxwGUQUuJL9BqCA0=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
              inherit (final.rpds-py) src;
              name = "rpds-py-vendor";
              hash = "sha256-0YwuSSV2BuD3f2tHDLRN12umkfSaJGIX9pw4/rf20V8=";
            };
          });

          watchfiles = prev.watchfiles.overridePythonAttrs (old: { preferWheel = true; });
        });

        postFixup = ''
          wrapProgram $out/bin/aider-vertex \
            --set VERTEX_PROJECT "gen-lang-client-0140206225" \
            --set VERTEX_LOCATION "us-central1" \
            --add-flags "--model vertex_ai/gemini-2.5-pro"
        '';
      };
    };
}
