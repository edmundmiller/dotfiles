# modules/dev/python.nix --- https://godotengine.org/
#
# Python's ecosystem repulses me. The list of environment "managers" exhausts
# me. The Py2->3 transition make trainwrecks jealous. But SciPy, NumPy, iPython
# and Jupyter can have my babies. Every single one.

{ config, options, lib, pkgs, my, ... }:

with lib;
with lib.my;
let cfg = config.modules.dev.python;
in {
  options.modules.dev.python = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      conda
      python37
      python37Packages.pip
      python37Packages.ipython
      python37Packages.black
      python37Packages.setuptools
      python37Packages.pylint
      python37Packages.poetry
      python37Packages.pytest
      (python37Packages.buildPythonPackage rec {
        pname = "pytest-workflow";
        version = "1.5.0";
        src = python37Packages.fetchPypi {
          inherit pname version;
          sha256 = "sha256-6+ZqR4ljvQQ9N+N38gQtWCVKD8a1ybKE1A0oajA+GkQ=";
        };
        nativeBuildInputs = [ python37Packages.twine ];
        propagatedBuildInputs = [
          python37Packages.pytest
          python37Packages.pyyaml
          python37Packages.jsonschema
        ];
        doCheck = false;
      })
    ];

    env.IPYTHONDIR = "$XDG_CONFIG_HOME/ipython";
    env.PIP_CONFIG_FILE = "$XDG_CONFIG_HOME/pip/pip.conf";
    env.PIP_LOG_FILE = "$XDG_DATA_HOME/pip/log";
    env.PYLINTHOME = "$XDG_DATA_HOME/pylint";
    env.PYLINTRC = "$XDG_CONFIG_HOME/pylint/pylintrc";
    env.PYTHONSTARTUP = "$XDG_CONFIG_HOME/python/pythonrc";
    env.PYTHON_EGG_CACHE = "$XDG_CACHE_HOME/python-eggs";
    env.JUPYTER_CONFIG_DIR = "$XDG_CONFIG_HOME/jupyter";

    environment.shellAliases = {
      py = "python";
      py2 = "python2";
      py3 = "python3";
      po = "poetry";
      ipy = "ipython --no-banner";
      ipylab = "ipython --pylab=qt5 --no-banner";
    };
  };
}
