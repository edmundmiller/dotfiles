{
  lib,
  python3,
  shfmt,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "snakefmt";
  version = "2.0.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "snakemake";
    repo = "snakefmt";
    rev = "v${version}";
    hash = "sha256-LMcsm+dAZG/eBLvv71mPmBIVuKu53nZarNScm72N5iY=";
  };

  build-system = [ python3.pkgs.hatchling ];
  pythonRemoveDeps = [ "shfmt-py" ];

  propagatedBuildInputs = with python3.pkgs; [
    black
    click
    importlib-metadata
    toml
    shfmt
  ];

  pythonImportsCheck = [ "snakefmt" ];

  meta = with lib; {
    description = "The uncompromising Snakemake code formatter";
    homepage = "https://github.com/snakemake/snakefmt";
    changelog = "https://github.com/snakemake/snakefmt/blob/${src.rev}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ edmundmiller ];
    mainProgram = "snakefmt";
  };
}
