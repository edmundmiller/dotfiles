{
  lib,
  fetchFromGitHub,
  python3,
}:
python3.pkgs.buildPythonPackage rec {
  pname = "omnivoreql";
  version = "0.3.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yazdipour";
    repo = "OmnivoreQL";
    rev = version;
    hash = "sha256-HiKgf2MmBtNdzoaN7tCcirU52o7dT3Cg08EEdCM6Cik=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  dependencies = [
    python3.pkgs.gql
    python3.pkgs.python-dotenv
    python3.pkgs.requests-toolbelt
  ];

  pythonImportsCheck = [
    "omnivoreql"
  ];

  meta = with lib; {
    description = "Omnivore-app API client for Python";
    homepage = "https://github.com/yazdipour/OmnivoreQL";
    license = licenses.mit;
    maintainers = with maintainers; [edmundmiller];
  };
}
