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
  version = "0-unstable-2026-05-28";

  src = fetchFromGitHub {
    owner = "jarredkenny";
    repo = "worktree-manager";
    rev = "0192f041a80cfc47e94d37c63a0f35e7c3c085d8";
    hash = "sha256-S3RX7EaNB3Lvt7+S4kYwQkNoqlKuDwNIRgAMZa+qFP0=";
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
