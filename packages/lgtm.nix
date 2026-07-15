{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "lgtm";
  version = "0-unstable-2026-07-14";

  src = fetchurl {
    url = "https://github.com/ellie/lgtm/releases/download/latest/LGTM.dmg";
    hash = "sha256-5fxCKtL7bShFrd2a07zFOrx7eYonDVtlLaWCoexN4QE=";
  };

  unpackPhase = ''
    runHook preUnpack
    mkdir mnt source
    /usr/bin/hdiutil attach "$src" -readonly -nobrowse -mountpoint "$PWD/mnt"
    trap '/usr/bin/hdiutil detach "$PWD/mnt"' EXIT
    cp -R mnt/LGTM.app source/
    /usr/bin/hdiutil detach "$PWD/mnt"
    trap - EXIT
    runHook postUnpack
  '';

  sourceRoot = "source";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R LGTM.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Fast native code-review app built with GPUI";
    homepage = "https://github.com/ellie/lgtm";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
