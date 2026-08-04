{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "writer-computer";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/joelbqz/writer-computer/releases/download/v${finalAttrs.version}/Writer.app.tar.gz";
    hash = "sha256-YaTxPbGeKJLEsIHbXDAbw64rugCIG/1+PCT/Be2id6U=";
  };

  sourceRoot = ".";
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R Writer.app "$out/Applications/"
    ln -s ../Applications/Writer.app/Contents/MacOS/desktop "$out/bin/writer"
    runHook postInstall
  '';

  meta = {
    description = "Fast, local-first markdown editor for macOS";
    homepage = "https://writer.computer";
    license = lib.licenses.gpl3Only;
    mainProgram = "writer";
    platforms = [ "aarch64-darwin" ];
  };
})
