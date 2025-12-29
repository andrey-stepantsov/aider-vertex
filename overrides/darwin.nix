{ pkgs, googleFix, unstable }:
final: prev:
let
  # Wrap unstable binaries to look like Python packages
  cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
  cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });

  # Define a safe, explicit SDK to avoid "apple_sdk_11_0 has been removed" errors.
  # We access frameworks from here instead of pkgs.darwin.apple_sdk
  frameworks = pkgs.darwin.apple_sdk_12_3.frameworks;
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

  # Dummy tools
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

  # --- SDK DEPRECATION FIXES ---
  # Explicitly overwrite inputs using 'frameworks' (SDK 12.3) to purge 11.0 references

  cryptography = prev.cryptography.overridePythonAttrs (old: {
    nativeBuildInputs = [ pkgs.pkg-config frameworks.Security pkgs.libiconv ];
    buildInputs = [ pkgs.openssl frameworks.Security pkgs.libiconv ];
  });

  cffi = prev.cffi.overridePythonAttrs (old: {
    nativeBuildInputs = [ pkgs.pkg-config pkgs.libffi ];
    buildInputs = [ pkgs.libffi ];
  });

  pyopenssl = prev.pyopenssl.overridePythonAttrs (old: {
    nativeBuildInputs = [];
    buildInputs = [ frameworks.Security ];
  });
  
  keyring = prev.keyring.overridePythonAttrs (old: {
    nativeBuildInputs = [ frameworks.Security frameworks.CoreFoundation ];
    buildInputs = [];
  });

  psutil = prev.psutil.overridePythonAttrs (old: {
    nativeBuildInputs = [ frameworks.IOKit frameworks.CoreFoundation ];
    buildInputs = [ frameworks.IOKit frameworks.CoreFoundation ];
  });

  watchfiles = prev.watchfiles.overridePythonAttrs (old: {
    nativeBuildInputs = [ 
      unstable.cargo unstable.rustc pkgs.rustPlatform.cargoSetupHook unstable.maturin 
      frameworks.CoreServices
    ];
    buildInputs = [ frameworks.CoreServices ];
  });

  sounddevice = prev.sounddevice.overridePythonAttrs (old: {
    nativeBuildInputs = [ frameworks.CoreAudio frameworks.AudioToolbox ];
    buildInputs = [ pkgs.portaudio ];
  });

  pyperclip = prev.pyperclip.overridePythonAttrs (old: {
    nativeBuildInputs = [ frameworks.Foundation frameworks.AppKit ];
  });

  numpy = prev.numpy.overridePythonAttrs (old: {
    nativeBuildInputs = [ frameworks.Accelerate ];
    buildInputs = [];
  });

  tiktoken = prev.tiktoken.overridePythonAttrs (old: {
    nativeBuildInputs = [ 
      pkgs.cargo pkgs.rustc pkgs.rustPlatform.cargoSetupHook pkgs.rustPlatform.maturinBuildHook 
      frameworks.Security 
    ];
  });
  
  tokenizers = prev.tokenizers.overridePythonAttrs (old: {
    nativeBuildInputs = [ 
      pkgs.cargo pkgs.rustc pkgs.rustPlatform.cargoSetupHook pkgs.rustPlatform.maturinBuildHook 
      frameworks.Security 
    ];
  });

  # Grafted Scipy (Unstable Binary)
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