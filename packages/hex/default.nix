{
  lib,
  rustPlatform,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  cargo,
  rustc,
  cmake,
  pkg-config,
  python3,
  unzip,
  writeShellScriptBin,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hex";
  version = "2.3.1";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "hex";
    rev = "c4b3287d86a74b0aeb26653375040dfa9b344f21"; # app-v2.3.1
    hash = "sha256-naO1Md+hjM5CatQZj2FbUA1QhkjAGkaPYpCcyYDXpLk=";
  };

  patches = [
    ./patches/0001-lazy-microphone-close.patch
    ./patches/0002-nix-managed-updates.patch
    ./patches/0003-nix-swift-macro-build.patch
  ];

  # Same lock and git dependency hashes as upstream's Nix package at this revision.
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${finalAttrs.src}/Cargo.lock";
    outputHashes = {
      "transcribe-rs-0.3.11" = "sha256-MJJiug3LfbKsuHcL2+LJk95+j5kk/MWzb5ihdBlHLmE=";
      "gpui-0.2.2" = "sha256-LtFxryxm3guT3e+Sa7sUI9u7ErplqMaWlJyaJlRguRw=";
    };
  };

  # Reuse this exact release's icons, command SDK, driver, and native runtime
  # libraries. Its executable is replaced with our source-built binary below.
  releaseBundle = fetchurl {
    url = "https://downloads.hex.kitlangton.dev/releases/HEX-${finalAttrs.version}-arm64.zip";
    hash = "sha256-qKgTM0ySxQXGXEzS8+Z44nWLGXOT32L5iCZMPoctTd0=";
  };

  nativeBuildInputs = [
    cargo
    rustc
    rustPlatform.cargoSetupHook
    cmake
    pkg-config
    python3
    unzip
    # Swift bridges in Cargo dependencies invoke `swift build` themselves.
    # Like Quill, avoid a nested sandbox and give SwiftPM writable directories.
    (writeShellScriptBin "swift" ''
      if [ "$1" = build ]; then
        shift
        exec /usr/bin/xcrun swift build --disable-sandbox \
          --cache-path "$TMPDIR/hex-swift-cache" \
          --config-path "$TMPDIR/hex-swift-config" \
          --security-path "$TMPDIR/hex-swift-security" "$@"
      fi
      exec /usr/bin/xcrun swift "$@"
    '')
  ];
  dontUseCmakeConfigure = true;
  dontFixup = true;

  # Like packages/quill: host Xcode, not a hermetic or cacheable Nix build.
  # Requires sandbox = relaxed or false; strict sandboxing rejects __noChroot.
  __noChroot = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  env = {
    HEX_NIX_MANAGED = "1";
    MACOSX_DEPLOYMENT_TARGET = "15.0";
    CC = "/usr/bin/clang";
    CXX = "/usr/bin/clang++";
    AR = "/usr/bin/ar";
    CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER = "/usr/bin/clang";
    CMAKE_ARGS = "-DGGML_NATIVE=OFF";
    # Rust 1.96's debuginfo stripping misaligns proc-macro dylibs on macOS 27.
    # Build dependencies are not shipped: https://github.com/rust-lang/rust/issues/157750
    CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP = "none";
  };

  # Use Cargo directly: buildRustPackage's build/check hooks override the host
  # compiler and linker with Nix clang, even when CC is set explicitly.
  buildPhase = ''
    runHook preBuild
    export PATH="$PATH:/usr/bin:/bin"
    # Override the SDK setup hook before probing host tools.
    unset DEVELOPER_DIR SDKROOT
    export DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
    export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
    for tool in swiftc metal metallib; do
      if ! /usr/bin/xcrun --find "$tool" >/dev/null 2>&1; then
        echo "hex requires full Xcode 26 or newer with the Metal toolchain ($tool missing)" >&2
        exit 1
      fi
    done
    # xcrun can find a shim even when the optional Metal component is absent.
    /usr/bin/xcrun metal --version
    export LIBCLANG_PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib"
    export HOME="$TMPDIR/hex-home"
    mkdir -p "$HOME"
    cargo build --frozen --release --target aarch64-apple-darwin -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    rustc --edition=2024 --test src/microphone_idle.rs -o "$TMPDIR/microphone-idle-tests"
    "$TMPDIR/microphone-idle-tests"
    cargo test --frozen --release --target aarch64-apple-darwin -j "$NIX_BUILD_CORES" \
      --bin voice-control dictation_audio::tests
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$TMPDIR/hex-release" "$out/Applications" "$out/bin"
    unzip -q "$releaseBundle" -d "$TMPDIR/hex-release"
    cp -R "$TMPDIR/hex-release/HEX.app" "$out/Applications/Hex.app"
    app="$out/Applications/Hex.app"
    chmod -R u+w "$app"
    install -m755 target/aarch64-apple-darwin/release/voice-control "$app/Contents/MacOS/hex"
    # The original signature no longer covers the executable. Ad-hoc signing
    # needs no developer identity, but macOS permissions may need regranting.
    /usr/bin/codesign --force --sign - --entitlements app/VoiceControl.entitlements "$app"
    /usr/bin/codesign --verify --deep --strict "$app"
    ln -s "$app/Contents/MacOS/hex" "$out/bin/hex"
    runHook postInstall
  '';

  meta = {
    description = "Local voice dictation with lazy microphone close (impure host-Xcode build)";
    homepage = "https://github.com/anomalyco/hex";
    license = lib.licenses.mit;
    mainProgram = "hex";
    platforms = [ "aarch64-darwin" ];
  };
})
