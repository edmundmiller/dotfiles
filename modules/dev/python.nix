{ config, lib, pkgs, ... }:

{
  # TODO Declare packages
  environment.systemPackages = with pkgs; [
    python37
    python37Packages.black
    python37Packages.setuptools
    python37Packages.pyaml
    python37Packages.poetry
    python27
    pipenv
    conda
  ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.python.zsh".source = <config/python/aliases.zsh>;
    "zsh/rc.d/env.python.zsh".source = <config/python/env.zsh>;
  };
}
