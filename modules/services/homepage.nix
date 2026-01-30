{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.homepage;
  homepagePort = 8082;
in
{
  options.modules.services.homepage = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = homepagePort;
      openFirewall = true;
      widgets = [
        {
          audiobookshelf = {
            url = "http://audiobookshelf.host.or.ip:port";
            key = "audiobookshelflapikey";
          };
        }
        # TODO Bazaar
        # TODO Calendar
        # TODO Health checks
        # TODO Home assistant
        # TODO Jellyfin
        # TODO Jellyseer
        # TODO NextDNS
        # TODO Paperless
        # TODO Radarr
        # TODO Scrutiny
        # TODO Speedtest tracker
        # TODO Tailscale
        # TODO romm
        # TODO sonarr
        # TODO transmission
      ];
    };

    environment.systemPackages = [ config.services.homepage-dashboard.package ];
  };
}
