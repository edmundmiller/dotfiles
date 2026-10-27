{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "voxtype-overlay";
  version = "0.1.0";
  dontUnpack = true;

  # AppKit builds use this Mac's Xcode SDK, like dji-mic-mini-receiver-mute.
  __noChroot = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  buildPhase = ''
    runHook preBuild
    export CLANG_MODULE_CACHE_PATH="$TMPDIR/clang-module-cache"
    export SWIFT_MODULECACHE_PATH="$TMPDIR/swift-module-cache"
    /usr/bin/xcrun swiftc -O -parse-as-library \
      ${./audio-level-feed.swift} ${./voxtype-overlay.swift} -o voxtype-overlay
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    /usr/bin/xcrun swiftc -parse-as-library \
      ${./audio-level-feed.swift} ${./_tests/audio-level-feed-test.swift} -o audio-level-feed-test
    ./audio-level-feed-test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 voxtype-overlay "$out/bin/"
    runHook postInstall
  '';

  meta = {
    description = "Click-through macOS recording waveform for Voxtype's audio level feed";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "voxtype-overlay";
  };
}
