{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  tmux,
  bash,
}:

stdenvNoCC.mkDerivation {
  pname = "tmux-palette";
  version = "0-unstable-2026-06-24";

  src = fetchFromGitHub {
    owner = "eduwass";
    repo = "tmux-palette";
    rev = "7caa11e845e0aa0515d013158df85613f3ec507f";
    hash = "sha256-Wrfo6G9Uuko0FYM9azwGNmyEYszSi/Tnwb71XY89QxI=";
  };

  nativeCheckInputs = [ bun ];

  doCheck = true;

  checkPhase = ''
    runHook preCheck

    export HOME=$(mktemp -d)
    bun test

    runHook postCheck
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p $out/share/tmux-palette $out/bin
        cp -R . $out/share/tmux-palette/

        substituteInPlace $out/share/tmux-palette/bin/tmux-palette.sh \
          --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash' \
          --replace-fail 'TMUX_BIN="$(command -v tmux)"' 'TMUX_BIN="${tmux}/bin/tmux"' \
          --replace-fail 'bun "$DIR/src/cli.ts"' '${bun}/bin/bun "$DIR/src/cli.ts"' \
          --replace-fail "exec bun '\$DIR/src/cli.ts'" "exec ${bun}/bin/bun '\$DIR/src/cli.ts'"

        cat > $out/bin/tmux-palette <<EOF
    #!${bash}/bin/bash
    exec $out/share/tmux-palette/bin/tmux-palette.sh "\$@"
    EOF
        chmod +x $out/bin/tmux-palette

        runHook postInstall
  '';

  meta = with lib; {
    description = "Raycast-style command palette for tmux";
    homepage = "https://github.com/eduwass/tmux-palette";
    license = licenses.mit;
    mainProgram = "tmux-palette";
    platforms = platforms.unix;
  };
}
