# hermes-vcc — lossless conversation archiving + structured compaction for Hermes.
#
# Packaged locally in dotfiles so we can iterate on the plugin code without
# waiting for upstream GitHub merges.  The source lives in packages/hermes-vcc/
# alongside this derivation.
#
# Exposes two outputs:
#   pkgs.my.hermes-vcc        — the Python library (hermes_vcc.*) installable via PYTHONPATH
#   pkgs.my.hermes-vcc.plugin — a store path containing plugins/memory/vcc/ for
#                               Hermes plugin discovery
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

  hermesVcc = python3Packages.buildPythonPackage {
    pname = "hermes-vcc";
    version = "0.2.0";
    format = "pyproject";

    inherit src;

    nativeBuildInputs = [ python3Packages.hatchling ];
    propagatedBuildInputs = [ python3Packages.pyyaml ];

    # Ship the plugins/ directory alongside the Python package so the hermes
    # module activation script can find it at a stable store path.
    postInstall = ''
      mkdir -p $out/share/hermes-vcc/plugins/memory/vcc
      cp ${src}/plugins/memory/vcc/__init__.py $out/share/hermes-vcc/plugins/memory/vcc/
      cp ${src}/plugins/memory/vcc/plugin.yaml  $out/share/hermes-vcc/plugins/memory/vcc/
    '';

    doCheck = false;

    meta = {
      description = "Lossless conversation archiving and structured compaction for Hermes agent";
      license = lib.licenses.asl20;
      maintainers = [ ];
    };
  };
in
hermesVcc
