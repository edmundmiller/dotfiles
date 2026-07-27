{
  lib,
  makeWrapper,
  nodejs_22,
  python312,
  python312Packages,
  fetchFromGitHub,
  symlinkJoin,
}:
let
  pyiceberg = python312Packages.pyiceberg.overridePythonAttrs (_: {
    doCheck = false;
    nativeCheckInputs = [ ];
    pythonRelaxDeps = [ "rich" ];
  });

  duckdb = python312Packages.duckdb.overridePythonAttrs (_: {
    doCheck = false;
    nativeCheckInputs = [ ];
  });

  narwhals = python312Packages.narwhals.overridePythonAttrs (_: {
    doCheck = false;
    nativeCheckInputs = [ ];
  });

  marimo = (python312Packages.marimo.override { inherit narwhals; }).overridePythonAttrs (_: {
    doCheck = false;
    nativeCheckInputs = [ ];
  });

  trajectory = python312Packages.buildPythonPackage rec {
    pname = "letta-trajectory";
    version = "0.2.0";
    pyproject = true;
    src = fetchFromGitHub {
      owner = "letta-ai";
      repo = "trajectory";
      rev = "v${version}";
      hash = "sha256-I1eqvRTbp0erFNqA0kFn/e2Bf1riy44JBS5YKXkVtmg=";
    };
    sourceRoot = src.name;
    build-system = [ python312Packages.setuptools ];
    pythonImportsCheck = [ "trajectory" ];
  };

  agentTraces = python312Packages.buildPythonPackage {
    pname = "agent-traces";
    version = "0.1.0";
    pyproject = true;
    src = ./.;
    build-system = [ python312Packages.setuptools ];
    dependencies = [
      duckdb
      marimo
      python312Packages.pyarrow
      python312Packages.pyiceberg-core
      python312Packages.sqlalchemy
      pyiceberg
      trajectory
    ];
    nativeCheckInputs = [
      nodejs_22
      python312Packages.pytestCheckHook
    ];
    pythonImportsCheck = [ "agent_traces" ];
  };

  pythonEnv = python312.withPackages (_: [ agentTraces ]);
in
symlinkJoin {
  name = "agent-traces-0.1.0";
  paths = [ pythonEnv ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/python" --prefix PATH : ${lib.makeBinPath [ nodejs_22 ]}
  '';
  passthru = {
    inherit agentTraces pythonEnv trajectory;
    notebook = ./notebooks/explore.py;
  };
  meta = {
    description = "Internal R2 Iceberg agent-session ingestion and query environment";
    platforms = lib.platforms.darwin;
  };
}
