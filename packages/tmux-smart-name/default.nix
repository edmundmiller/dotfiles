{
  lib,
  stdenv,
  bun,
  nodejs,
}:

stdenv.mkDerivation {
  pname = "tmux-smart-name";
  version = "0.3.0";

  src = ./.;

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    mkdir -p dist
    bun build src/index.ts --outdir dist --target node

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/tmux-smart-name/{dist,scripts}
    cp dist/index.js $out/share/tmux-smart-name/dist/
    cp scripts/smart-name.sh $out/share/tmux-smart-name/scripts/

    chmod +x $out/share/tmux-smart-name/scripts/smart-name.sh

    # Patch shebang in the bundled JS
    substituteInPlace $out/share/tmux-smart-name/dist/index.js \
      --replace-quiet '#!/usr/bin/env node' '#!${nodejs}/bin/node' || true

    # Patch the shell script to use nix store node
    substituteInPlace $out/share/tmux-smart-name/scripts/smart-name.sh \
      --replace-fail 'node "$MAIN"' '${nodejs}/bin/node "$MAIN"'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Smart tmux window naming with AI agent status detection";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
