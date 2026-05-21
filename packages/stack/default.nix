{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  inputs,
}:

let
  bun2nix = inputs.bun2nix.packages.${stdenv.hostPlatform.system}.default;
in
stdenv.mkDerivation rec {
  pname = "stack";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "kitlangton";
    repo = "stack";
    rev = "v${version}";
    hash = "sha256-E9ATGUzY373/1uVIgUdTe2F//yF6Qchhit0NgiBpids=";
  };

  patches = [
    ./fix-explicit-chain.patch
  ];

  nativeBuildInputs = [
    bun2nix.hook
    makeWrapper
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  buildPhase = ''
    runHook preBuild
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/stack $out/bin
    cp -R dist skills README.md LICENSE package.json $out/lib/stack/

    makeWrapper ${nodejs}/bin/node $out/bin/stack \
      --add-flags $out/lib/stack/dist/cli.js

    runHook postInstall
  '';

  meta = {
    description = "Squash-safe stacked PR repair CLI";
    homepage = "https://github.com/kitlangton/stack";
    license = lib.licenses.mit;
    mainProgram = "stack";
  };
}
