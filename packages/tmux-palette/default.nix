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
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "eduwass";
    repo = "tmux-palette";
    rev = "ecc9e23da4f772ff3c2f4e91613d8fd25241d6d0";
    hash = "sha256-JAbGD99M7TrYFmLhNB6GgkNwwAEBNq/7AGu17vNjKu4=";
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
