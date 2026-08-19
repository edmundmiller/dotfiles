{
  lib,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "0.0.3";
  sources = {
    aarch64-darwin = fetchurl {
      url = "https://releases.fx.sh/v${version}/fx-macos-aarch64.tar.gz";
      hash = "sha256-h8STliGwwCjkUG8YQWuHIt7Q26zmNYOAARQAyO0Seos=";
    };
    x86_64-linux = fetchurl {
      url = "https://releases.fx.sh/v${version}/fx-linux-x86_64.tar.gz";
      hash = "sha256-I9MuYCM7JFgbnOGWW2W6tqRtVpOiSt14F4VK7zrfW/s=";
    };
  };
  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "fx: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fx";
  inherit version src;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 fx "$out/bin/fx"
    runHook postInstall
  '';

  meta = {
    description = "Tiny, open, native coding agent";
    homepage = "https://fx.sh";
    license = lib.licenses.asl20;
    mainProgram = "fx";
    platforms = builtins.attrNames sources;
  };
}
