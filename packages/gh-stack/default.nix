{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.3.0";
  sources = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      sha256 = "70c0cb11346ad5d4f97a02a5cf5242052254d1775d356dc0759f035457873850";
    };
    x86_64-darwin = {
      asset = "darwin-amd64";
      sha256 = "edea1d5f3ec80fe6596f44d438604b05846fcbcac3fff0707dbe7071794bd6a9";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      sha256 = "803ec91eeba9b2ac38827e299a79830fe75ca7284f0c28d60e6a2704bb34ed13";
    };
    x86_64-linux = {
      asset = "linux-amd64";
      sha256 = "957e822cfa7e435cd84a297cd96c419b58e51e3ac58be249762c24bd9e45099b";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "gh-stack";
  inherit version;

  src = fetchurl {
    url = "https://github.com/github/gh-stack/releases/download/v${version}/${source.asset}";
    inherit (source) sha256;
  };

  dontUnpack = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/gh-stack"
    runHook postInstall
  '';

  meta = {
    description = "GitHub CLI extension for stacked branches and pull requests";
    homepage = "https://github.com/github/gh-stack";
    changelog = "https://github.com/github/gh-stack/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "gh-stack";
    platforms = builtins.attrNames sources;
  };
}
