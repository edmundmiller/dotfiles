# Dagster OSS — data orchestration platform
#
# Produces a Python environment with dagster-webserver, dagster-daemon,
# and dagster CLI on $PATH. Used by modules/services/dagster/.
#
# Update: bump `version` + `postgresVersion`, then replace all hashes
# with `lib.fakeHash` and rebuild to get new hashes.
{
  lib,
  python3,
  fetchPypi,
}:
let
  version = "1.12.15";
  postgresVersion = "0.28.15";

  py = python3;
  ps = py.pkgs;

  # -- dagster-pipes (zero deps) --
  dagster-pipes = ps.buildPythonPackage rec {
    pname = "dagster-pipes";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      pname = "dagster_pipes";
      inherit version;
      hash = "sha256-kY2E17ojwsvionL5uTC2b8+B8zSxf6D8aEcNwbfr8ws=";
    };

    build-system = [ ps.setuptools ];
    dependencies = [ ];

    # Tests require dagster (circular)
    doCheck = false;

    meta = {
      description = "Dagster pipes - lightweight API for integrating with Dagster from external processes";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

  # -- dagster-shared --
  dagster-shared = ps.buildPythonPackage rec {
    pname = "dagster-shared";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      pname = "dagster_shared";
      inherit version;
      hash = "sha256-WawkyoWBTxQxbGMgPrX0W+nYfGuykGGXAsW2oqO4O3g=";
    };

    build-system = [ ps.setuptools ];

    dependencies = with ps; [
      packaging
      platformdirs
      pydantic
      pyyaml
      tomlkit
      typing-extensions
    ];

    doCheck = false;

    meta = {
      description = "Shared utilities for dagster packages";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

  # -- dagster (core) --
  dagster-core = ps.buildPythonPackage rec {
    pname = "dagster";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-+NI0ZvAO26Uvhoq/Z3Pec3p+8SEYKVTT+8VL07cuUhI=";
    };

    build-system = [ ps.setuptools ];

    # nixpkgs has coloredlogs 15.x, dagster pins <=14.0 but works fine
    pythonRelaxDeps = [ "coloredlogs" ];
    nativeBuildInputs = [ ps.pythonRelaxDepsHook ];

    dependencies = with ps; [
      dagster-pipes
      dagster-shared
      alembic
      antlr4-python3-runtime
      click
      coloredlogs
      docstring-parser
      filelock
      grpcio
      grpcio-health-checking
      jinja2
      protobuf
      python-dotenv
      pytz
      requests
      rich
      setuptools
      six
      sqlalchemy
      structlog
      tabulate
      tomli
      toposort
      tqdm
      tzdata
      universal-pathlib
      watchdog
    ];

    doCheck = false;

    meta = {
      description = "Dagster - the data orchestration platform";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

  # -- dagster-graphql --
  dagster-graphql = ps.buildPythonPackage rec {
    pname = "dagster-graphql";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      pname = "dagster_graphql";
      inherit version;
      hash = "sha256-N3CwNRsOLSiSFNMlVgUwWt8k4idX9Vv3CQLzWH/hLhE=";
    };

    build-system = [ ps.setuptools ];

    dependencies = with ps; [
      dagster-core
      graphene
      gql
      requests
      requests-toolbelt
      starlette
    ];

    doCheck = false;

    meta = {
      description = "Dagster GraphQL API";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

  # -- dagster-webserver --
  dagster-webserver = ps.buildPythonPackage rec {
    pname = "dagster-webserver";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      pname = "dagster_webserver";
      inherit version;
      hash = "sha256-+WracEPPS2yUOeIpqDZQ5BX5aPHhwbh/X0eK/CsENU4=";
    };

    build-system = [ ps.setuptools ];

    dependencies = with ps; [
      dagster-core
      dagster-graphql
      click
      starlette
      uvicorn
    ];

    doCheck = false;

    meta = {
      description = "Dagster webserver - serves the Dagster UI";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

  # -- dagster-postgres --
  dagster-postgres = ps.buildPythonPackage rec {
    pname = "dagster-postgres";
    version = postgresVersion;
    pyproject = true;

    src = fetchPypi {
      pname = "dagster_postgres";
      inherit version;
      hash = "sha256-ydMt1g2NPSdrlCzmi8b4WKfeKY7U+Q+9YnO1dqx+cUY=";
    };

    build-system = [ ps.setuptools ];

    # Wants psycopg2-binary but nixpkgs psycopg2 provides the same thing
    pythonRelaxDeps = [ "psycopg2-binary" ];
    pythonRemoveDeps = [ "psycopg2-binary" ];
    nativeBuildInputs = [ ps.pythonRelaxDepsHook ];

    dependencies = with ps; [
      dagster-core
      psycopg2
    ];

    doCheck = false;

    meta = {
      description = "Dagster PostgreSQL storage backend";
      homepage = "https://dagster.io";
      license = lib.licenses.asl20;
    };
  };

in
# Combined environment with all binaries on PATH
py.withPackages (_: [
  dagster-core
  dagster-webserver
  dagster-graphql
  dagster-postgres
  dagster-pipes
  dagster-shared
])
