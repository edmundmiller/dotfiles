{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  version = "0.43.0";
in
stdenvNoCC.mkDerivation {
  pname = "agento11y";
  inherit version;

  src = fetchurl {
    url = "https://github.com/grafana/agento11y/releases/download/plugins/agento11y/v${version}/agento11y_${version}_darwin_arm64.tar.gz";
    hash = "sha256-YKvVTByWBOwm0R9b/WOQw9PPJ97g6ACSdHYU8Mvcnh8=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 agento11y "$out/bin/agento11y"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/agento11y" --version)" = "v${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Grafana observability for coding agents";
    homepage = "https://github.com/grafana/agento11y";
    license = lib.licenses.asl20;
    mainProgram = "agento11y";
    platforms = [ "aarch64-darwin" ];
  };
}
