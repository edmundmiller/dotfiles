{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    direnv
    (import <nixpkgs-unstable> { }).lorri
  ];

  home-manager.users.emiller = {
    xdg.configFile = {
      "zsh/rc.d/aliases.direnv.zsh".source = <config/direnv/aliases.zsh>;
      "direnv/direnvrc".source = <config/direnv/direnvrc>;
    };
  };
}
