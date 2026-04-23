{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  git,
}:

stdenv.mkDerivation {
  pname = "worktree-manager";
  version = "1.3.0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "jarredkenny";
    repo = "worktree-manager";
    rev = "6b0b65f53e867abcf99c836cc78a6f101a1a65f2";
    hash = "sha256-3ziOhhrD0ExZnJykT7gptF8q+o1XolnyO9ywhWDob6Q=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    bun install --frozen-lockfile
    mkdir -p dist
    bun build index.ts --outfile dist/index.js --target bun --format esm

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir=$out/lib/worktree-manager
    mkdir -p "$appDir" "$out/bin"

    cp -r dist package.json "$appDir"/

    makeWrapper ${bun}/bin/bun $out/bin/wtm \
      --add-flags "$appDir/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [ git ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Git worktree manager CLI used by jmux for bare-repo workflows";
    homepage = "https://github.com/jarredkenny/worktree-manager";
    license = licenses.mit;
    mainProgram = "wtm";
    platforms = platforms.all;
  };
}
