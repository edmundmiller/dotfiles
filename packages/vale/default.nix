{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  version = "3.18.0";
  sources = {
    x86_64-linux = {
      archive = "vale_${version}_Linux_64-bit.tar.gz";
      hash = "sha256-pvcadaEv5ok0W3VPJBK5A2f+M2SKu30gD6Geqtwtv20=";
    };
    aarch64-darwin = {
      archive = "vale_${version}_macOS_arm64.tar.gz";
      hash = "sha256-TX3pvag3naFM1FBIUAGZxUlBMYdSbQkTODrYIoZq1D0=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "vale: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "vale";
  inherit version;

  src = fetchurl {
    url = "https://github.com/vale-cli/vale/releases/download/v${version}/${source.archive}";
    inherit (source) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 vale "$out/bin/vale"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Syntax-aware linter for prose";
    homepage = "https://vale.sh/";
    license = licenses.mit;
    mainProgram = "vale";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
