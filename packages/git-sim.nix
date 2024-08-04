{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "git-sim";
  version = "0.3.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "initialcommit-com";
    repo = "git-sim";
    rev = "v${version}";
    hash = "sha256-F8A29ZWL2lPTlqwOV6bbbuL/0MZvitxi9GJWrdu69zI=";
  };

  nativeBuildInputs = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  pythonImportsCheck = [ "git_sim" ];

  meta = with lib; {
    description = "Visually simulate Git operations in your own repos with a single terminal command";
    homepage = "https://github.com/initialcommit-com/git-sim";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ ];
    mainProgram = "git-sim";
  };
}
