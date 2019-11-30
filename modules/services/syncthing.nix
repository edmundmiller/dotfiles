{ config, lib, pkgs, ... }:

{
  users.users.emiller.extraGroups = [ "syncthing" ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "emiller";
    configDir = "/home/emiller/.config/syncthing";
    dataDir = "/home/emiller/sync";
  };
}
