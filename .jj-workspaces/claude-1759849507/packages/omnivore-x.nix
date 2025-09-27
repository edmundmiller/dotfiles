{
  lib,
  python3,
  fetchFromGitHub,
  my,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "omnivore-x";
  version = "0.0.15";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yazdipour";
    repo = "OmnivoreX";
    rev = "v${version}";
    hash = "sha256-hxxWdPGtaiWuWqLMGeZUSCg6YhDADhAxlqY4u2d4b44=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  dependencies = with python3.pkgs; [
    my.omnivoreql
    python-dotenv
    textual
  ];

  # pythonImportsCheck = [
  #   "omnivore_x"
  # ];
  pythonRuntimeDepsCheck = false;

  meta = with lib; {
    description = "Omnivore TUI Terminal Client [Windows - MacOS - Linux";
    homepage = "https://github.com/yazdipour/OmnivoreX";
    license = licenses.mit;
    maintainers = with maintainers; [ edmundmiller ];
    mainProgram = "omnivore-x";
  };
}
