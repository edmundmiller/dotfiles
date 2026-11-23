{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "spaceman";
  version = "0.3.3";

  # The Homebrew cask named spaceman is an unrelated menu-bar app.
  # Use the immutable, signed Anomaly release rather than the latest redirect.
  src = fetchurl {
    url = "https://anoma.ly/release/spaceman/files/8540e3ba79340425d3605dbc7ac97c428ea19669b5c05b45a6b6d795ed566681/Spaceman.zip";
    hash = "sha256-hUDjunk0BCXTYF28esl8Qo6hlmm1wFtFprbXle1WZoE=";
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
