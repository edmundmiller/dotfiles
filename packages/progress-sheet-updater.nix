{ lib, python3Packages, fetchFromGitHub, pkgs }:

python3Packages.buildPythonApplication rec {
  pname = "progress-sheet-updater";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "emiller88";
    repo = "Progress-Sheet-Updater";
    rev = "setup";
    sha256 = "sha256-NCw8Ki6FFhyPcOzUQSEqXREa4WssC/240lLI0wCOg8w=";
  };

  propagatedBuildInputs = with python3Packages; [
    google_api_python_client
    google-auth-oauthlib
    protobuf
    watchdog
  ];

  meta = with lib; {
    homepage = "https://github.com/VoltaicHQ/Progress-Sheet-Updater";
    description = "No description, website, or topics provided.";
    license = licenses.gpl3;
    maintainers = with maintainers; [ emiller88 ];
  };
}
