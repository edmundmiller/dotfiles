{
  lib,
  python3,
  stdenvNoCC,
}:

let
  appPython = python3.withPackages (
    ps: with ps; [
      google-api-python-client
      google-auth-oauthlib
      google-auth-httplib2
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "work-calendar-busy";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp work-calendar-busy "$out/bin/work-calendar-busy"
    chmod +x "$out/bin/work-calendar-busy"

    substituteInPlace "$out/bin/work-calendar-busy" \
      --replace-fail '#!/usr/bin/env python3' '#!${appPython}/bin/python'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Calendar freebusy-only CLI with macOS Keychain token storage";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    mainProgram = "work-calendar-busy";
    platforms = platforms.darwin;
  };
}
