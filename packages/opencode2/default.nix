{
  lib,
  stdenvNoCC,
  fetchurl,
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

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/opencode2"
    cp -R bin/. "$out/lib/opencode2/"
    ln -s "$out/lib/opencode2/opencode2" "$out/bin/opencode2"
    runHook postInstall
  '';

  meta = {
    description = "OpenCode 2.0 beta CLI";
    homepage = "https://v2.opencode.ai/";
    license = lib.licenses.mit;
    mainProgram = "opencode2";
    platforms = [ "aarch64-darwin" ];
  };
}
