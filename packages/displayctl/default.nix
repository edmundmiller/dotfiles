{
  lib,
  python3,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "displayctl";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/displayctl"
    cp displayctl "$out/bin/displayctl"
    cp config.json "$out/share/displayctl/config.json"
    chmod +x "$out/bin/displayctl"

    substituteInPlace "$out/bin/displayctl" \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agent-friendly standard-library CLI for BUSY Bar and TRMNL displays";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    mainProgram = "displayctl";
    platforms = platforms.unix;
  };
}
