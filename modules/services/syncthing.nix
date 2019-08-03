{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "emiller";
    dataDir = "/home/emiller/Sync";
    configDir = "/home/emiller/.config/syncthing";
  };
}
