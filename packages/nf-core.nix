{
  lib,
  python3,
  fetchFromGitHub,
}: let
  pname = "nf-core";
  version = "2.10";
in
  python3.pkgs.buildPythonApplication rec {
    inherit pname version;
    pyproject = true;

    src = fetchFromGitHub {
      owner = "nf-core";
      repo = "tools";
      rev = version;
      hash = "sha256-1yk8PWOUoz1f2sGsPTbgKHn40tjoSgrTx/GgoQzlveo=";
    };

    nativeBuildInputs = [
      python3.pkgs.setuptools
      python3.pkgs.wheel
    ];

    propagatedBuildInputs = with python3.pkgs; [
      click
      filetype
      gitpython
      jinja2
      jsonschema
      markdown
      packaging
      prompt-toolkit
      pytest
      pyyaml
      questionary
      requests
      requests-cache
      rich
      rich-click
      tabulate
    ];

    pythonImportsCheck = ["nf_core"];

    meta = with lib; {
      description = "Python package with helper tools for the nf-core community";
      homepage = "https://github.com/nf-core/tools";
      changelog = "https://github.com/nf-core/tools/blob/${src.rev}/CHANGELOG.md";
      license = licenses.mit;
      maintainers = with maintainers; [emiller88];
      mainProgram = "tools";
    };
  }
