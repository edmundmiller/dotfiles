{ config, options, pkgs, lib, my, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.tailscale;
in
{
  options.modules.services.tailscale = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;

    networking.firewall = {
      allowedTCPPorts = [ 41641 ];
      allowedUDPPorts = [ 41641 ];
    };
  };
}
