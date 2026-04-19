{
  lib,
  stdenvNoCC,
  fetchzip,
  nodejs,
}:

stdenvNoCC.mkDerivation rec {
  pname = "slop-scan";
  version = "0.3.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-8borpUSYTu1bs2BfznbFImEeOxHp7+qCFpG82WB3XGw=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r dist $out/

    install -Dm755 bin/slop-scan.js $out/bin/slop-scan
    substituteInPlace $out/bin/slop-scan \
      --replace-fail '#!/usr/bin/env node' '#!${nodejs}/bin/node'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Deterministic CLI for finding AI-associated slop patterns in JS/TS repos";
    homepage = "https://github.com/modem-dev/slop-scan";
    license = licenses.mit;
    mainProgram = "slop-scan";
    platforms = platforms.all;
    maintainers = [ ];
  };
}
