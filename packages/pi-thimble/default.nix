{ lib, runCommand }:
let
  source = ../pi-packages/pi-thimble;
in
runCommand "pi-thimble-0.1.0"
  {
    meta = {
      description = "Pi-native TypeScript evidence, labeling, and coverage tools";
      homepage = "https://github.com/safety-research/thimble";
      license = lib.licenses.asl20;
      platforms = lib.platforms.unix;
    };
  }
  ''
    mkdir -p "$out"
    cp ${source}/package.json ${source}/index.ts ${source}/thimble-*.ts \
      ${source}/README.md ${source}/LICENSE ${source}/NOTICE "$out/"
    rm -f "$out/"*.test.ts
  ''
