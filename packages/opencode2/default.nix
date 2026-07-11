{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:

stdenvNoCC.mkDerivation rec {
  pname = "opencode2";
  version = "0.0.0-next-15330";

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode-ai/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
    hash = "sha512-Q0g/Prm3FxTS70voyOEcrbNGX+TMVqQldoFmkYoYqq7eaVbIPNT1Wo/6YAqK2dvvnD0AGKq3ukZAzL//7D1riA==";
  };

  sourceRoot = "package";
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/opencode2"
    cp -R bin/. "$out/lib/opencode2/"
    makeWrapper "$out/lib/opencode2/opencode2" "$out/bin/opencode" \
      --run 'export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config/opencode2}"'
    ln -s opencode "$out/bin/opencode2"
    runHook postInstall
  '';

  meta = {
    description = "OpenCode 2.0 beta CLI";
    homepage = "https://v2.opencode.ai/";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "aarch64-darwin" ];
  };
}
