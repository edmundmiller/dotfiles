{
  lib,
  inputs,
  stdenvNoCC,
  buildNpmPackage,
  nodejs,
  fetchurl,
  linkFarm,
}:
let
  inherit (inputs.nixpkgs-jj.legacyPackages.${stdenvNoCC.hostPlatform.system})
    cargo
    rustc
    rustPlatform
    ;
  clean =
    path:
    lib.cleanSourceWith {
      src = path;
      filter =
        name: _:
        !(builtins.elem (baseNameOf name) [
          "target"
          "node_modules"
          ".models"
        ]);
    };
  engine = buildNpmPackage {
    pname = "tinytype-engine";
    version = "0.1.0";
    src = clean ./engine;
    npmDepsHash = "sha256-I9TSUDv54mnZPjgg6znuPE5Qo5BNCdDKRDX1wA+cVo0=";
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p "$out"
      cp -R node_modules package.json tinyfix-worker.mjs "$out/"
    '';
  };
  manifest = builtins.fromJSON (builtins.readFile ./engine/models.json);
  models = linkFarm "tinytype-models" (
    lib.mapAttrsToList (name: sha256: {
      inherit name;
      path = fetchurl {
        url = "https://huggingface.co/paperweight/tinyfix/resolve/${manifest.revision}/${name}";
        inherit sha256;
      };
    }) manifest.files
  );
in
stdenvNoCC.mkDerivation {
  pname = "tinytype";
  version = "0.1.0";
  src = clean ./.;
  # Rune intentionally carries a patched tiny-skia-path alongside crates.io's
  # same-version crate. Separate per-source vendor directories preserve both.
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = lib.fileset.toSource {
      root = ./.;
      fileset = ./Cargo.lock;
    };
    hash = "sha256-WdxTyewyPGcw6odeKUbmc9pL4/jD0Q3v2e/0sW1Mahk=";
  };
  nativeBuildInputs = [
    cargo
    rustc
    rustPlatform.cargoSetupHook
  ];
  # Like Hex and Quill, use host Xcode. Never substitute or remotely build this.
  __noChroot = true;
  preferLocalBuild = true;
  allowSubstitutes = false;
  dontFixup = true;
  env = {
    MACOSX_DEPLOYMENT_TARGET = "15.0";
    CC = "/usr/bin/clang";
    CXX = "/usr/bin/clang++";
    AR = "/usr/bin/ar";
    CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER = "/usr/bin/clang";
    CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP = "none";
  };
  buildPhase = ''
    runHook preBuild
    export PATH="$PATH:/usr/bin:/bin"
    unset DEVELOPER_DIR SDKROOT
    export DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
    export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
    export HOME="$TMPDIR/tinytype-home"
    mkdir -p "$HOME"
    cargo build --frozen --release -j "$NIX_BUILD_CORES"
    /usr/bin/xcrun swiftc -O -parse-as-library native/FocusedText.swift \
      native/AccessibilityGuide.swift -o target/focused-text
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cargo test --frozen --release -j "$NIX_BUILD_CORES"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    bash scripts/bundle-app.sh target/release/tinytype target/focused-text \
      ${nodejs}/bin/node ${engine} ${models} "$out/Applications/TinyType.app"
    mkdir -p "$out/bin"
    ln -s "$out/Applications/TinyType.app/Contents/MacOS/tinytype" "$out/bin/tinytype"
    runHook postInstall
  '';
  passthru = { inherit engine models; };
  meta = {
    description = "Offline macOS autocorrect with TinyFix and Rune (host-Xcode build)";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "tinytype";
  };
}
