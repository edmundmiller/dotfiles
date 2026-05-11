{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.5.7";

  assets = {
    aarch64-darwin = {
      name = "herdr-macos-aarch64";
      hash = "sha256-DJc/WRaPZPZ3NYcahLQs2iXCvzMIi1s0vRQFNHXPdJ8=";
    };
    x86_64-darwin = {
      name = "herdr-macos-x86_64";
      hash = "sha256-4yK1AqfuwvTx/mwYPmsvwvfWhQC0Lx87o6MlFSVi4MY=";
    };
    aarch64-linux = {
      name = "herdr-linux-aarch64";
      hash = "sha256-6K7mEnMh4C09MCMk46oWnXxoR/rwRbWCm8/2g9lkaBc=";
    };
    x86_64-linux = {
      name = "herdr-linux-x86_64";
      hash = "sha256-yOhfy4pHmavqzu2+Qx8mpg3VvBCArqwuNL8p/GBunqo=";
    };
  };

  asset =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "herdr: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/herdr"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = licenses.agpl3Plus;
    mainProgram = "herdr";
    platforms = attrNames assets;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
