{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "dji-mic-mini-receiver-mute";
  version = "0-unstable-2026-08-25";

  dontUnpack = true;

  # The helper imports Apple's CoreAudio SDK, which nixpkgs does not ship.
  # Build it with the local Command Line Tools and never substitute/cache it.
  __noChroot = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  buildPhase = ''
    runHook preBuild
    if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
      echo "dji-mic-mini-receiver-mute requires Xcode Command Line Tools" >&2
      exit 1
    fi
    export CLANG_MODULE_CACHE_PATH="$TMPDIR/clang-module-cache"
    export SWIFT_MODULECACHE_PATH="$TMPDIR/swift-module-cache"
    /usr/bin/xcrun swiftc \
      -parse-as-library \
      ${./receiver-mute.swift} \
      -o dji-mic-mini-receiver-mute
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 dji-mic-mini-receiver-mute "$out/bin/"
    runHook postInstall
  '';

  meta = {
    description = "Toggle input mute for the exact DJI Mic Mini receiver";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "dji-mic-mini-receiver-mute";
  };
}
