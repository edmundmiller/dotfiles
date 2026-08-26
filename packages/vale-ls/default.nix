{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:
let
  version = "0.5.0";
  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-H+qmBgE1edFws7oa9Lwm/p4oHYA+bQpzwLfBvqnKCRc=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-Fi7n6Pzg74jyY3d8IWoL2Uo4TwWK5Uumj8m7zbqrgrs=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "vale-ls: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "vale-ls";
  inherit version;

  src = fetchurl {
    url = "https://github.com/vale-cli/vale-ls/releases/download/v${version}/vale-ls-${source.target}.zip";
    inherit (source) hash;
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    unzip -q "$src"
    install -Dm755 vale-ls "$out/bin/vale-ls"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Language server for Vale";
    homepage = "https://github.com/vale-cli/vale-ls";
    license = licenses.mit;
    mainProgram = "vale-ls";
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
  };
}
