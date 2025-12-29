{ pkgs, googleFix, unstable }:
final: prev:
let
  cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
  cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });
  
  frameworks = pkgs.darwin.apple_sdk.frameworks;

  # Helper to sanitise SDK inputs. 
  # It effectively wipes out whatever poetry2nix added and sets safe defaults.
  fixDarwinSDK = pkg: extraNative: extraBuild: pkg.overridePythonAttrs (old: {
    nativeBuildInputs = [ pkgs.pkg-config pkgs.libiconv ] ++ extraNative;
    buildInputs = [ pkgs.libiconv ] ++ extraBuild;
  });

  # Helper for Rust/Maturin packages
  fixRustSDK = pkg: extraFrameworks: pkg.overridePythonAttrs (old: {
    nativeBuildInputs = [ 
      unstable.cargo unstable.rustc pkgs.rustPlatform.cargoSetupHook unstable.maturin 
      pkgs.pkg-config pkgs.libiconv 
    ] ++ extraFrameworks;
    buildInputs = [ pkgs.libiconv ] ++ extraFrameworks;
  });

in
{
  google-cloud-aiplatform = prev.google-cloud-aiplatform.overridePythonAttrs googleFix;
  google-cloud-storage = prev.google-cloud-storage.overridePythonAttrs googleFix;
  google-cloud-core = prev.google-cloud-core.overridePythonAttrs googleFix;
  google-api-core = prev.google-api-core.overridePythonAttrs googleFix;
  google-resumable-media = prev.google-resumable-media.overridePythonAttrs googleFix;
  google-crc32c = prev.google-crc32c.overridePythonAttrs googleFix;
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  meson = pkgs.python311Packages.buildPythonPackage {
    pname = "meson";
    version = unstable.meson.version;
    format = "other";
    src = ./.; 
    unpackPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${cleanMesonBinary}/bin/meson $out/bin/meson
      site_packages=$out/lib/python3.11/site-packages
      mkdir -p $site_packages/meson-${unstable.meson.version}.dist-info
      echo "Metadata-Version: 2.1" > $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
      echo "Name: meson" >> $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
      echo "Version: ${unstable.meson.version}" >> $site_packages/meson-${unstable.meson.version}.dist-info/METADATA
      ln -s ${cleanMesonBinary}/lib/python*/site-packages/mesonbuild $site_packages/mesonbuild
    '';
    propagatedBuildInputs = [ cleanMesonBinary ];
  };

  ninja = pkgs.python311Packages.buildPythonPackage {
    pname = "ninja";
    version = unstable.ninja.version;
    format = "other";
    src = ./.; 
    unpackPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${cleanNinjaBinary}/bin/ninja $out/bin/ninja
      site_packages=$out/lib/python3.11/site-packages
      mkdir -p $site_packages/ninja-${unstable.ninja.version}.dist-info
      echo "Metadata-Version: 2.1" > $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
      echo "Name: ninja" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
      echo "Version: ${unstable.ninja.version}" >> $site_packages/ninja-${unstable.ninja.version}.dist-info/METADATA
    '';
    propagatedBuildInputs = [ cleanNinjaBinary ];
  };

  pybind11 = prev.pybind11.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.ninja ];
  });

  meson-python = prev.meson-python.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.meson ];
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ final.meson ];
  });

  # --- SDK FIXES ---
  
  cryptography = fixDarwinSDK prev.cryptography 
    [ frameworks.Security ] 
    [ pkgs.openssl frameworks.Security ];

  cffi = fixDarwinSDK prev.cffi 
    [ pkgs.libffi ] 
    [ pkgs.libffi ];

  pyopenssl = fixDarwinSDK prev.pyopenssl [] [ frameworks.Security ];
  
  keyring = fixDarwinSDK prev.keyring 
    [ frameworks.Security frameworks.CoreFoundation ] [];

  psutil = fixDarwinSDK prev.psutil 
    [ frameworks.IOKit frameworks.CoreFoundation ] 
    [ frameworks.IOKit frameworks.CoreFoundation ];

  sounddevice = fixDarwinSDK prev.sounddevice 
    [ frameworks.CoreAudio frameworks.AudioToolbox ] 
    [ pkgs.portaudio ];

  pyperclip = fixDarwinSDK prev.pyperclip 
    [ frameworks.Foundation frameworks.AppKit ] [];

  numpy = fixDarwinSDK prev.numpy 
    [ frameworks.Accelerate ] [];

  # Fix Rust/Maturin packages
  # Pydantic-core is a prime suspect for using Security framework defaults
  pydantic-core = fixRustSDK prev.pydantic-core 
    [ frameworks.Security frameworks.SystemConfiguration frameworks.CoreFoundation ];

  tiktoken = fixRustSDK prev.tiktoken 
    [ frameworks.Security ];
  
  tokenizers = fixRustSDK prev.tokenizers 
    [ frameworks.Security ];

  watchfiles = fixRustSDK prev.watchfiles 
    [ frameworks.CoreServices ];

  # Fix C-extension packages
  pyyaml = fixDarwinSDK prev.pyyaml [] [];
  markupsafe = fixDarwinSDK prev.markupsafe [] [];

  # Grafted Scipy
  scipy = unstable.python311Packages.scipy;

  # GRAFTED RPDS-PY
  rpds-py = pkgs.python311Packages.buildPythonPackage {
    pname = "rpds-py";
    version = unstable.python311Packages.rpds-py.version;
    format = "pyproject";
    inherit (unstable.python311Packages.rpds-py) src cargoDeps;
    patches = unstable.python311Packages.rpds-py.patches or [];
    cargoPatches = unstable.python311Packages.rpds-py.cargoPatches or [];
    postPatch = unstable.python311Packages.rpds-py.postPatch or "";
    dontCheckRuntimeDeps = true;
    nativeBuildInputs = [
      unstable.cargo unstable.rustc pkgs.rustPlatform.cargoSetupHook unstable.maturin pkgs.pkg-config
      pkgs.libiconv frameworks.Security frameworks.SystemConfiguration
    ];
    buildInputs = [ pkgs.libiconv ];
    buildPhase = ''
      export CARGO_HOME=$PWD/.cargo
      maturin build --jobs=$NIX_BUILD_CORES --frozen --release --strip --manylinux off
      mkdir -p dist
      mv target/wheels/*.whl dist/
    '';
  };
}