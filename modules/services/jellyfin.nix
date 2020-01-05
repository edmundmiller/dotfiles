{ config, lib, pkgs, ... }:

{
  services.jellyfin = { enable = true; };

  networking.firewall = {
    allowedTCPPorts = [ 8096 ];
    allowedUDPPorts = [ 8096 ];
  };
}
