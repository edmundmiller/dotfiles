{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "betteraudio";
  version = "26.6.2";

  src = fetchurl {
    url = "https://github.com/rokartur/BetterAudio/releases/download/${finalAttrs.version}/BetterAudio-${finalAttrs.version}.zip";
    hash = "sha256-oLCKKlsEH02FibtLf0wnzy2We31+8ve/0JD0OuHwGas=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    unzip -q "$src" -d "$out/Applications"
    runHook postInstall
  '';

  meta = {
    description = "Per-app volume control and audio device manager for macOS";
    homepage = "https://github.com/rokartur/BetterAudio";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
  };
})
