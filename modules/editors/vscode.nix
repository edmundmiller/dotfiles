{ config, lib, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  home-manager.users.emiller = {
    programs.vscode = {
      enable = true;
      package = pkgs.vscodium;
      userSettings = { };
    };
  };
}
