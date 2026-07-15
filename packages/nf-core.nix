{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  prek,
}:
let
  pname = "nf-core";
  version = "4.0.2";
  py = python3.pkgs;
  mkPypi =
    {
      pname,
      version,
      hash,
      dependencies ? [ ],
      buildSystem ? [
        py.setuptools
        py.wheel
      ],
      importName ? pname,
    }:
    py.buildPythonPackage {
      inherit pname version dependencies;
      pyproject = true;
      src = fetchPypi { inherit pname version hash; };
      build-system = buildSystem;
      pythonImportsCheck = [ importName ];
      dontCheckRuntimeDeps = true;
    };
  arcp = mkPypi {
    pname = "arcp";
    version = "0.2.1";
    hash = "sha256-XBeseXLJ74KXnMLK8rOofBrv0/7+mtuKXdcoraV3Fd0=";
  };
  rocrate = mkPypi {
    pname = "rocrate";
    version = "0.15.1";
    hash = "sha256-T0z27qZlWbqp2bjxCuBuBhG6E+s2RO3Hg7333QBy/O0=";
    dependencies = [
      arcp
      py.click
      py.jinja2
      py.python-dateutil
      py.requests
    ];
  };
  repo2rocrate = mkPypi {
    pname = "repo2rocrate";
    version = "0.1.2";
    hash = "sha256-rhIMNRgPhSoY3ujG6hFNwMZauqERsmo9qH1PIR3X7tw=";
    dependencies = [
      py.click
      py.pyyaml
      rocrate
    ];
  };
  trogon = mkPypi {
    pname = "trogon";
    version = "0.6.0";
    hash = "sha256-/Rq/63sV151ubPyeckqtKicogS5HE6dE2XXxM+fsc6Q=";
    buildSystem = [ py.poetry-core ];
    dependencies = [
      py.click
      py.textual
    ];
  };
  pdiff = mkPypi {
    pname = "pdiff";
    version = "1.1.5";
    hash = "sha256-ZcOhq2cGCjN/A8DKy7zSS/vxvxeWHKGzh19HZidFp9U=";
    dependencies = [ py.colorama ];
  };
  logmuse = mkPypi {
    pname = "logmuse";
    version = "0.3.0";
    hash = "sha256-KYwzNsvKBJ3i89bUvB6kyl2dYVTHSPNM/IbonTHj/J8=";
    buildSystem = [ py.hatchling ];
  };
  ubiquerg = mkPypi {
    pname = "ubiquerg";
    version = "0.9.3";
    hash = "sha256-O0CUN3Bh/VQlz8nxCGVDfywB2QoNkz0IaC14ncPk7Og=";
    buildSystem = [ py.hatchling ];
  };
  yacman = mkPypi {
    pname = "yacman";
    version = "1.0.0";
    hash = "sha256-ID2BWXCcbyunyyyZyW8Dht46LTD8HSbDgibxbR+MG1U=";
    buildSystem = [ py.hatchling ];
    dependencies = [
      py.pyyaml
      ubiquerg
    ];
  };
  refgenconf = mkPypi {
    pname = "refgenconf";
    version = "0.13.1";
    hash = "sha256-RlPVraFjonFu9h+DQgfFV2HQrWgcggShpIc+83COsCc=";
    dependencies = [
      py.pyfaidx
      py.pyyaml
      py.requests
      py.rich
      py.tqdm
      ubiquerg
      yacman
    ];
  };
  pipestat = mkPypi {
    pname = "pipestat";
    version = "0.13.1";
    hash = "sha256-h89pQEUR5DTo6aIKvf2cgSOtbS94GKGCop23cqjXjUc=";
    buildSystem = [ py.hatchling ];
    dependencies = [
      logmuse
      py.jinja2
      py.jsonschema
      py.pyyaml
      ubiquerg
      yacman
    ];
  };
  piper = mkPypi {
    pname = "piper";
    version = "0.15.1";
    hash = "sha256-D9LU1Eg92snG/v0AW5XqUopxWcnn9yoIW7TTba9v/50=";
    buildSystem = [ py.hatchling ];
    importName = "pypiper";
    dependencies = [
      logmuse
      pipestat
      py.psutil
      ubiquerg
      yacman
    ];
  };
  refgenie = mkPypi {
    pname = "refgenie";
    version = "0.13.0";
    hash = "sha256-3BoTK0kv64lQ9Zc3qH6pYmyNQA9ygEHKPdk62GBQRAQ=";
    dependencies = [
      logmuse
      piper
      py.pyfaidx
      py.requests
      py.rich
      refgenconf
      ubiquerg
      yacman
    ];
  };
in
python3.pkgs.buildPythonApplication rec {
  inherit pname version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "nf-core";
    repo = "tools";
    rev = version;
    hash = "sha256-UclYmIf7LUmfn0jdjtozD7/vNcA/FY3w4nCTsNaTN+A=";
  };

  nativeBuildInputs = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  propagatedBuildInputs =
    (with py; [
      click
      filetype
      gitpython
      jinja2
      jsonschema
      markdown
      packaging
      pillow
      prompt-toolkit
      pydantic
      pygithub
      pyyaml
      questionary
      requests
      requests-cache
      rich
      rich-click
      ruamel-yaml
      setuptools
      tabulate
      textual
    ])
    ++ [
      pdiff
      prek
      refgenie
      repo2rocrate
      rocrate
      trogon
    ];
  pythonRemoveDeps = [ "prek" ];
  pythonRelaxDeps = [
    "setuptools"
    "textual"
  ];

  pythonImportsCheck = [ "nf_core" ];

  meta = with lib; {
    description = "Python package with helper tools for the nf-core community";
    homepage = "https://github.com/nf-core/tools";
    changelog = "https://github.com/nf-core/tools/blob/${src.rev}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ emiller88 ];
    mainProgram = "nf-core";
  };
}
