{
  lib,
  fetchurl,
  stdenvNoCC,
  makeWrapper,
}:
let
  version = "0.0.4";
  sources = {
    aarch64-darwin = fetchurl {
      url = "https://releases.fx.sh/v${version}/fx-macos-aarch64.tar.gz";
      hash = "sha256-OVrDgy9vbCMfa6eka6bscO763baGYub9bE+44NbXL1k=";
    };
    x86_64-linux = fetchurl {
      url = "https://releases.fx.sh/v${version}/fx-linux-x86_64.tar.gz";
      hash = "sha256-vpQoY2r7EZbLZitI7Ve77TuV58N/K8eEngLAlg+uHwE=";
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
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 fx "$out/bin/fx"
    # Nix store binaries cannot be replaced in place.
    wrapProgram "$out/bin/fx" --set FX_AUTO_UPGRADE 0
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
