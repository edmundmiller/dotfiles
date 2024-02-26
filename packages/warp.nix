{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  appimageTools,
}: let
  pname = "warp-terminal";
  version = "0.2024.02.20.08.01.stable_01";

  linux = appimageTools.wrapType2 {
    inherit pname version;
    src = fetchurl {
      url = "https://releases.warp.dev/stable/v${version}/Warp-x86_64.AppImage";
      hash = "sha256-541IHjrtUGzZwQh5+q4M27/UF2ZTqhznPX6ieh2nqUQ=";
    };
  };

  darwin = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit pname version;
    src = fetchurl {
      url = "https://releases.warp.dev/stable/v${finalAttrs.version}/Warp.dmg";
      hash = "sha256-9olAmczIPRXV15NYCOYmwuEmJ7lMeaQRTTfukaYXMR0=";
    };

    sourceRoot = ".";

    nativeBuildInputs = [undmg];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -r *.app $out/Applications

      runHook postInstall
    '';
  });

  meta = with lib; {
    description = "Rust-based terminal";
    homepage = "https://www.warp.dev";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    maintainers = with maintainers; [emilytrau Enzime];
    platforms = platforms.darwin;
  };
in
  if stdenvNoCC.isDarwin
  then darwin
  else linux
