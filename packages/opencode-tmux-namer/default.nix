{
  lib,
  stdenv,
  bun,
}:

stdenv.mkDerivation {
  pname = "opencode-tmux-namer";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    bun install --frozen-lockfile
    
    # Use bun's native transpiler (no node/tsc needed)
    mkdir -p dist
    bun build src/index.ts --outdir dist --target node

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist $out/
    cp package.json $out/

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode plugin for dynamic tmux window naming";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
