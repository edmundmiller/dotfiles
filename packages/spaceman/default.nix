{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "spaceman";
  version = "0.0.0-dev-226";

  # The Homebrew cask named spaceman is an unrelated menu-bar app.
  # Pin the installed dev build so the shared Labs/Hyper config stays supported.
  src = fetchurl {
    url = "https://anoma.ly/release/spaceman/files/920a24506c377dd8d9aed900febece86ed8c5acc2e3b7e3925d6acd6dbcb5c25/Spaceman.zip";
    hash = "sha256-kgokUGw3fdjZrtkA/r7Ohu2MWswuO345Jdas1tvLXCU=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  # Preserve the upstream Developer ID signature, including Sparkle helpers.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    unzip -q "$src" -d "$out/Applications"
    ln -s "$out/Applications/Spaceman.app/Contents/MacOS/spaceman" "$out/bin/spaceman"
    runHook postInstall
  '';

  meta = {
    description = "Anomaly's tiling window manager for macOS";
    homepage = "https://anoma.ly/spaceman/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "spaceman";
  };
}
