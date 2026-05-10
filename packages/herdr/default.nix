{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.5.6";

  assets = {
    aarch64-darwin = {
      name = "herdr-macos-aarch64";
      hash = "sha256-PN3OvG7P9l/Q0ZmkBYYUDlQSI8v5iu24FZ/DdyjCiAk=";
    };
    x86_64-darwin = {
      name = "herdr-macos-x86_64";
      hash = "sha256-mpm74Asks6fLL6jfMXF4Wh0ShRFRBagSaOAaig+v17U=";
    };
    aarch64-linux = {
      name = "herdr-linux-aarch64";
      hash = "sha256-hnqn8Nvo7ZpswxaAthh96z+53xyCk8J8tYByydZ6CgE=";
    };
    x86_64-linux = {
      name = "herdr-linux-x86_64";
      hash = "sha256-C0kwvHQ68v4oaZdrISbu7KdNZtnLQGQw5ICJhzpflXg=";
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
