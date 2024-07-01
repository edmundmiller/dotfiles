{ lib
, python3
, fetchFromGitHub
}:

python3.pkgs.buildPythonApplication rec {
  pname = "snakefmt";
  version = "0.10.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "snakemake";
    repo = "snakefmt";
    rev = "v${version}";
    hash = "sha256-Sp48yedUiL8NCF7WF9QdvaOGocPXIBZ5bXXj7r4RVIM=";
  };

  nativeBuildInputs = [
    python3.pkgs.poetry-core
  ];

  propagatedBuildInputs = with python3.pkgs; [
    black
    click
    importlib-metadata
    toml
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
