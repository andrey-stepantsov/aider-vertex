{ pkgs, googleFix, unstable }:
final: prev:
let
  # Wrap unstable binaries to look like Python packages
  cleanMesonBinary = unstable.meson.overrideAttrs (old: { setupHook = null; });
  cleanNinjaBinary = unstable.ninja.overrideAttrs (old: { setupHook = null; });

  # SAFE SDK SOURCE:
  # Points to the current default SDK frameworks in Nixpkgs Unstable.
  # This bypasses the deprecated 'apple_sdk_11_0' aliases that cause crashes.
  frameworks = pkgs.darwin.apple_sdk.frameworks;

  # HELPER: Clobber C-extension inputs.
  # This completely overwrites nativeBuildInputs/buildInputs to remove
  # any poisoned defaults injected by poetry2nix.
  fixDarwinSDK = pkg: extraNative: extraBuild: pkg.overridePythonAttrs (old: {
    nativeBuildInputs = [ pkgs.pkg-config pkgs.libiconv ] ++ extraNative;
    buildInputs = [ pkgs.libiconv ] ++ extraBuild;
  });

  # HELPER: Clobber Rust/Maturin inputs.
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
  google-cloud-resource-manager = prev.google-cloud-resource-manager.overridePythonAttrs googleFix;
  google-cloud-bigquery = prev.google-cloud-bigquery.overridePythonAttrs googleFix;

  # --- DUMMY TOOLS (Required for builds that still trigger) ---
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

  # --- MASSIVE SDK CLEANUP (Removing deprecated apple_sdk_11_0) ---

  # Cryptography Stack
  cryptography = fixDarwinSDK prev.cryptography [ frameworks.Security ] [ pkgs.openssl frameworks.Security ];
  cffi = fixDarwinSDK prev.cffi [ pkgs.libffi ] [ pkgs.libffi ];
  pyopenssl = fixDarwinSDK prev.pyopenssl [] [ frameworks.Security ];
  keyring = fixDarwinSDK prev.keyring [ frameworks.Security frameworks.CoreFoundation ] [];

  # Networking / Google Stack
  grpcio = fixDarwinSDK prev.grpcio 
    [ pkgs.cmake pkgs.ninja frameworks.CoreFoundation ] 
    [ pkgs.openssl pkgs.zlib frameworks.CoreFoundation ];
  grpcio-status = fixDarwinSDK prev.grpcio-status [] [];
  
  # Combined fix for google-crc32c (License fix + SDK fix)
  google-crc32c = let
    patched = prev.google-crc32c.overridePythonAttrs googleFix;
  in fixDarwinSDK patched [] [];

  # AIOHTTP Stack
  aiohttp = fixDarwinSDK prev.aiohttp [] [];
  multidict = fixDarwinSDK prev.multidict [] [];
  yarl = fixDarwinSDK prev.yarl [] [];
  frozenlist = fixDarwinSDK prev.frozenlist [] [];
  aiosignal = fixDarwinSDK prev.aiosignal [] [];
  brotli = fixDarwinSDK prev.brotli [] [];

  # Web/Async Stack
  tornado = fixDarwinSDK prev.tornado [] [];
  pyzmq = fixDarwinSDK prev.pyzmq [ pkgs.zeromq ] [ pkgs.zeromq ];
  wrapt = fixDarwinSDK prev.wrapt [] [];
  msgpack = fixDarwinSDK prev.msgpack [] [];

  # Pillow
  pillow = fixDarwinSDK prev.pillow 
    [ pkgs.pkg-config ] 
    [ pkgs.libjpeg pkgs.zlib pkgs.libtiff pkgs.freetype pkgs.libwebp pkgs.openjpeg pkgs.libxcrypt ];

  # System Interaction
  psutil = fixDarwinSDK prev.psutil 
    [ frameworks.IOKit frameworks.CoreFoundation ] 
    [ frameworks.IOKit frameworks.CoreFoundation ];
  
  # Pyperclip: Removed SDK inputs to avoid confusion, let it be pure python/system call based
  pyperclip = fixDarwinSDK prev.pyperclip [] [];
  
  sounddevice = fixDarwinSDK prev.sounddevice 
    [ frameworks.CoreAudio frameworks.AudioToolbox ] 
    [ pkgs.portaudio ];
  
  # Git Stack
  gitpython = fixDarwinSDK prev.gitpython [] [];
  gitdb = fixDarwinSDK prev.gitdb [] [];
  smmap = fixDarwinSDK prev.smmap [] [];

  # Data / Formats
  numpy = fixDarwinSDK prev.numpy [ frameworks.Accelerate ] [];
  pyyaml = fixDarwinSDK prev.pyyaml [] [];
  markupsafe = fixDarwinSDK prev.markupsafe [] [];
  pandas = fixDarwinSDK prev.pandas [] [];
  pyarrow = fixDarwinSDK prev.pyarrow [ pkgs.cmake pkgs.ninja ] [ pkgs.arrow-cpp ];
  protobuf = fixDarwinSDK prev.protobuf [ pkgs.cmake ] [ pkgs.protobuf ];
  lxml = fixDarwinSDK prev.lxml [ pkgs.libxml2 pkgs.libxslt ] [ pkgs.libxml2 pkgs.libxslt ];

  # Rust / Maturin Stack
  pydantic-core = fixRustSDK prev.pydantic-core 
    [ frameworks.Security frameworks.SystemConfiguration frameworks.CoreFoundation ];
  tiktoken = fixRustSDK prev.tiktoken [ frameworks.Security ];
  tokenizers = fixRustSDK prev.tokenizers [ frameworks.Security ];
  
  # Watchfiles uses Rust (maturin) + CoreServices
  watchfiles = let
    base = fixRustSDK prev.watchfiles [ frameworks.CoreServices ];
  in base.overridePythonAttrs (old: { preferWheel = true; });

  # --- GRAFTED SCIPY ---
  scipy = unstable.python311Packages.scipy;

  # --- GRAFTED RPDS-PY ---
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