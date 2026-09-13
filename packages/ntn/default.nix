{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  version = "0.23.4";
  platforms = {
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ntn";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/ntn/-/ntn-${version}.tgz";
    hash = "sha256-qfDquYFuZz7/3wMJogKOR8xKW+lVO9V5MCI9Yw9HiOQ=";
  };

  sourceRoot = "package";
  dontStrip = true;

  # The npm installer only copies the matching native binary into bin/ntn.
  installPhase = ''
    runHook preInstall
    install -Dm755 dist/ntn-${platforms.${stdenvNoCC.hostPlatform.system}}/ntn "$out/bin/ntn"
    install -Dm644 LICENSE.md "$out/share/licenses/ntn/LICENSE.md"
    runHook postInstall
  '';

  meta = {
    description = "Official Notion CLI for API requests and Notion Workers";
    homepage = "https://developers.notion.com/cli/get-started/overview";
    license = lib.licenses.mit;
    mainProgram = "ntn";
    platforms = builtins.attrNames platforms;
  };
}
