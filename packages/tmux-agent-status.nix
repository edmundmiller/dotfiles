{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
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
    ./tmux-agent-status/patches/0002-force-expand-current-session.patch
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out"/

    # Force bash v4+ for associative-array scripts on macOS.
    # Upstream uses /usr/bin/env bash, which resolves to bash 3.2 on Darwin.
    find "$out/scripts" -type f -name '*.sh' -print0 | while IFS= read -r -d $'\0' f; do
      if head -1 "$f" | grep -q '^#!/usr/bin/env bash$'; then
        substituteInPlace "$f" --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash'
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "tmux session status/switcher/sidebar plugin with local expansion patches";
    homepage = "https://github.com/samleeney/tmux-agent-status";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
