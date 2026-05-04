{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.5.4";

  assets = {
    aarch64-darwin = {
      name = "herdr-macos-aarch64";
      hash = "sha256-2bVw0yEFEQU3t/iDH6gJD4l/WIMDPQTYuGLxHT6BPoc=";
    };
    x86_64-darwin = {
      name = "herdr-macos-x86_64";
      hash = "sha256-ofF4BqVz2uH2ci7lIEybLwOUn76XpibbyqU/pIEhEXo=";
    };
    aarch64-linux = {
      name = "herdr-linux-aarch64";
      hash = "sha256-PL2I6MQEQ3TqwY5UYw3RGHUTGLQlKTHU322uUqrzZPA=";
    };
    x86_64-linux = {
      name = "herdr-linux-x86_64";
      hash = "sha256-TAmxUY92ko7aMz/uaG6H8+d2O9La1nh6EtnpVuNoT4c=";
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
