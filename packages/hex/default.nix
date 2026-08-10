{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hex";
  version = "0.8.4";

  src = fetchurl {
    url = "https://github.com/kitlangton/Hex/releases/download/v${finalAttrs.version}/Hex-${finalAttrs.version}.zip";
    hash = "sha256-bmM/mw6RIxajNvyKAg2ldCycVFA0h8DA8ArHYnzvDLo=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    unzip -q "$src" -d "$out/Applications"
    find "$out/Applications" -name '._*' -delete
    runHook postInstall
  '';

  meta = {
    description = "On-device voice-to-text app for macOS";
    homepage = "https://github.com/kitlangton/Hex";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
  };
})
