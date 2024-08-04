{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "multiqc";
  version = "1.18";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ewels";
    repo = "MultiQC";
    rev = "v${version}";
    hash = "sha256-KnhLktPMsoXBEtzLTP7xV+x5Nx+yE+d4D44EuyIfvjI=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    python3.pkgs.importlib-metadata
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  propagatedBuildInputs = with python3.pkgs; [
    matplotlib
    networkx
    numpy
    click
    coloredlogs
    future
    jinja2
    markdown
    packaging
    pyyaml
    requests
    rich
    rich-click
    # FIXME spectra
    humanize
    # FIXME pyaml-env
  ];

  pythonImportsCheck = [ "multiqc" ];

  meta = with lib; {
    description = "Aggregate results from bioinformatics analyses across many samples into a single report";
    homepage = "https://github.com/ewels/MultiQC";
    changelog = "https://github.com/ewels/MultiQC/blob/${src.rev}/CHANGELOG.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ emiller88 ];
    mainProgram = "multiqc";
  };
}
