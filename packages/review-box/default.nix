{
  bun,
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "review-box";
  version = "0.1.0";
  src = ../pi-packages;

  nativeBuildInputs = [ bun ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p node_modules
    ln -s ../pi-herdr node_modules/pi-herdr
    bun build --compile pi-review-box/src/cli.ts --outfile review-box
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 review-box $out/bin/review-box
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      /usr/bin/codesign -f -s - $out/bin/review-box
    ''}
    runHook postInstall
  '';

  meta = {
    description = "Promote or resume Herdr Review Boxes from ghui";
    mainProgram = "review-box";
    platforms = lib.platforms.unix;
  };
}
