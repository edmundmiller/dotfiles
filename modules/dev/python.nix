# modules/dev/python.nix --- https://godotengine.org/
#
# Python's ecosystem repulses me. The list of environment "managers" exhausts
# me. The Py2->3 transition make trainwrecks jealous. But SciPy, NumPy, iPython
# and Jupyter can have my babies. Every single one.
{
  config,
  options,
  lib,
  pkgs,
  my,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.dev.python;
  my-python-packages = p: with p; [pandas requests seaborn];
in {
  options.modules.dev.python = {
    enable = mkBoolOpt false;
    conda.enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [
        conda
        (pkgs.python3.withPackages my-python-packages)
        python3Packages.pip
        python3Packages.black
        python3Packages.isort
        python3Packages.ipython
        python3Packages.jupyterlab
        python3Packages.setuptools
        python3Packages.pylint
        poetry
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
    }

    (mkIf cfg.conda.enable {
      user.packages = with pkgs; [unstable.micromamba];

      env.MAMBA_ROOT_PREFIX = "$XDG_DATA_HOME/mamba";

      environment.shellAliases.mm = "micromamba";
    })
  ]);
}
