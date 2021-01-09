{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.k3s;
in {
  imports = [ inputs.k3s-flake.nixosModules.k3s-flake ];
  options.modules.services.k3s = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.k3s-flake= {
      enable = true;
      role = "server";
      extraFlags = "--no-deploy servicelb --no-deploy traefik";
      docker = true;
    };
    networking.firewall.allowedTCPPorts = [ 6443 ];
  };
}