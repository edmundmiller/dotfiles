{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "audio-priority-bar";
  version = "1.2.1";

  src = fetchzip {
    url = "https://github.com/tobi/AudioPriorityBar/releases/download/v${version}/AudioPriorityBar.zip";
    hash = "sha256-HyuHO2Xk6dadmiNE1eZZcJRQ0PoNMbTYGE+GyFhNEUo=";
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R AudioPriorityBar.app "$out/Applications/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Native macOS menu bar app for managing audio device priorities";
    homepage = "https://github.com/tobi/AudioPriorityBar";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
