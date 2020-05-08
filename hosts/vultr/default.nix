{ config, options, pkgs, ... }:

{
  imports = [
    ../personal.nix # common settings
    ./hardware-configuration.nix
  ];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };

    shell = { zsh.enable = true; };

    services = {
      ssh.enable = true;
      syncthing.enable = true;
    };
  };

  networking.networkmanager.enable = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 15d";
  };

  my.packages = with pkgs; [ vim ];

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
