{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.qb;
  homeDir = config.users.users.${config.user.name}.home;
in
{
  options.modules.services.qb = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      gluetun = {
        image = "qmcgaw/gluetun";
        ports = [
          "8888:8888/tcp" # HTTP proxy
          "8388:8388/tcp" # Shadowsocks
          "8388:8388/udp" # Shadowsocks
          "8090:8090" # port for qbittorrent
        ];
        environmentFiles = [ config.age.secrets.qb.path ];
        # Give the container NET_ADMIN
        extraOptions = [ "--cap-add=NET_ADMIN" ];
      };

      qbittorrent = {
        image = "linuxserver/qbittorrent";
        dependsOn = [ "gluetun" ];
        user = "568:568";
        environment = {
          PUID = "568";
          PGID = "568";
          TZ = "America/Chicago";
          WEBUI_PORT = "8090";
        };
        volumes = [
          "${homeDir}/gluetun/config:/config"
          "/srv/nfs:/media"
        ];
        extraOptions = [ "--network=container:gluetun" ];
      };
    };
  };
}
