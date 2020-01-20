{ config, lib, pkgs, ... }:

{
  # This doesn't work on RockPro64
  # TODO set this based on CPU
  # services.jellyfin = { enable = true; };

  docker-containers = {
    "jellyfin" = {
      image = "jellyfin/jellyfin";
      volumes = [
        "/var/lib/jellyfin/config:/config"
        "/var/cache/jellyfin:/cache"
        "/data/media:/media"
      ];
      extraDockerOptions = [ "--net=host" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8096 ];
    allowedUDPPorts = [ 8096 ];
  };

  my.user.extraGroups = [ "jellyfin" ];
}
