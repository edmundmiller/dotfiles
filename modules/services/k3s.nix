{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.k3s;
in {
  options.modules.services.k3s = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.k3s = {
      enable = true;
      package = pkgs.unstable.k3s;
      role = "server";
      docker = true;
      extraFlags = "--no-deploy servicelb --no-deploy traefik";
      # serverAddr = "https://192.168.1.121:6443";
    };

    networking.firewall.allowedTCPPorts = [
      80
      443 # nginx
      6443 # k8s
    ];
    networking.firewall.allowedUDPPorts = [ 8472 ];
    networking.firewall.extraCommands = ''
      iptables -I INPUT 3 -s 10.42.0.0/16 -j ACCEPT
      iptables -I INPUT 3 -d 10.42.0.0/16 -j ACCEPT
    '';

    # Ceph
    boot.kernelModules = [ "ceph" "rbd" ];
    environment.systemPackages = [ pkgs.lvm2 ];

    user.extraGroups = [ "568" ];
  };
}
