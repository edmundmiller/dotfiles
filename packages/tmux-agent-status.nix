{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "tmux-agent-status";
  version = "main-unstable";

  src = fetchFromGitHub {
    owner = "samleeney";
    repo = "tmux-agent-status";
    rev = "main";
    hash = "sha256-HsDoMjEsXpzPSB77hYhrA0kMV0M35DgqbSTTIaHwDvA=";
  };

  patches = [
    ./tmux-agent-status/patches/0001-auto-expand-active-sessions.patch
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out"/
    runHook postInstall
  '';

  meta = with lib; {
    description = "tmux session status/switcher/sidebar plugin with local expansion patches";
    homepage = "https://github.com/samleeney/tmux-agent-status";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
