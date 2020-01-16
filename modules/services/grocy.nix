{ config, lib, pkgs, ... }:

{
  docker-containers = {
    "grocy" = {
      image = "linuxserver/grocy";
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "America/Chicago"; # TODO set from time.timeZone
      };
      ports = [ "9283:80" ];
      volumes = [ "/var/lib/grocy/config:/config" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 9283 ];
    allowedUDPPorts = [ 9283 ];
  };
}
