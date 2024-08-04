{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
  gql,
  python-dotenv,
  requests-toolbelt,
}:

buildPythonPackage rec {
  pname = "omnivore-ql";
  version = "0.3.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yazdipour";
    repo = "OmnivoreQL";
    rev = version;
    hash = "sha256-HiKgf2MmBtNdzoaN7tCcirU52o7dT3Cg08EEdCM6Cik=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    gql
    python-dotenv
    requests-toolbelt
  ];

  pythonImportsCheck = [
    "omnivore_ql"
  ];

  meta = with lib; {
    description = "Omnivore-app API client for Python";
    homepage = "https://github.com/yazdipour/OmnivoreQL";
    license = licenses.mit;
    maintainers = with maintainers; [ edmundmiller ];
  };
}
