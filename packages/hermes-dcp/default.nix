{
  lib,
  python3Packages,
}:

let
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      !(builtins.elem base [
        ".venv"
        ".pytest_cache"
        "__pycache__"
        "dist"
        ".git"
      ])
      && !(lib.hasSuffix ".pyc" path)
      && !(lib.hasSuffix ".pyo" path)
      && !(lib.hasSuffix ".egg-info" path);
  };

  hermesDcp = python3Packages.buildPythonPackage {
    pname = "hermes-dcp";
    version = "0.1.0";
    format = "pyproject";

    inherit src;

    nativeBuildInputs = [ python3Packages.hatchling ];
    propagatedBuildInputs = [ python3Packages.pyyaml ];

    postInstall = ''
      mkdir -p $out/share/hermes-dcp/plugins/dcp
      cp ${src}/plugins/dcp/__init__.py $out/share/hermes-dcp/plugins/dcp/
      cp ${src}/plugins/dcp/plugin.yaml  $out/share/hermes-dcp/plugins/dcp/
    '';

    doCheck = false;

    meta = {
      description = "DCP-style dynamic context pruning engine for Hermes";
      license = lib.licenses.mit;
      maintainers = [ ];
    };
  };
in
hermesDcp
