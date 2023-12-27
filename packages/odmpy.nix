{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "odmpy";
  version = "0.8.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ping";
    repo = "odmpy";
    rev = version;
    hash = "sha256-RWaB/W8ilAKRr0ZSISisCG8Mdgw5LXRCLOl5o1RsmbA=";
  };

  nativeBuildInputs = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  propagatedBuildInputs = with python3.pkgs; [
    beautifulsoup4
    eyed3
    iso639-lang
    lxml
    mutagen
    requests
    termcolor
    tqdm
    typing-extensions
  ];

  pythonImportsCheck = ["odmpy"];

  meta = with lib; {
    description = "A simple command line manager for OverDrive/Libby loans. Download your library loans from the command line";
    homepage = "https://github.com/ping/odmpy";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [];
    mainProgram = "odmpy";
  };
}
