{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "oauth2ms";
  version = "0-unstable-2021-07-10";
  format = "other";

  src = fetchFromGitHub {
    owner = "harishkrupo";
    repo = "oauth2ms";
    rev = "a1ef0cabfdea57e9309095954b90134604e21c08";
    hash = "sha256-xPSWlHJAXhhj5I6UMjUtH1EZqCZWHJMFWTu3a4k1ETc=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 oauth2ms "$out/bin/oauth2ms"
    patchShebangs "$out/bin/oauth2ms"
    runHook postInstall
  '';

  propagatedBuildInputs = with python3.pkgs; [
    pyxdg
    msal
    python-gnupg
  ];

  meta = with lib; {
    description = "";
    homepage = "https://github.com/harishkrupo/oauth2ms";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    mainProgram = "oauth2ms";
    platforms = platforms.all;
  };
}
