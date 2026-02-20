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
  tailnet = "cinnamon-rooster.ts.net";
  nucBase = "http://nuc.${tailnet}";
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

      # Allow access from tailscale hostname
      allowedHosts = "localhost:${toString homepagePort},nuc.${tailnet}:${toString homepagePort}";

      settings = {
        title = "NUC";
        favicon = "https://nixos.org/favicon.png";
        theme = "dark";
        color = "slate";
        headerStyle = "clean";
        hideVersion = true;
      };

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {
          datetime = {
            text_size = "xl";
            format = {
              timeStyle = "short";
              dateStyle = "short";
              hourCycle = "h23";
            };
          };
        }
        {
          search = {
            provider = "duckduckgo";
            target = "_blank";
          };
        }
      ];

      services = [
        {
          "Media" = [
            {
              "Jellyfin" = {
                href = "${nucBase}:8096";
                description = "Media server";
                icon = "jellyfin.svg";
              };
            }
            {
              "Audiobookshelf" = {
                href = "${nucBase}:13378";
                description = "Audiobooks & podcasts";
                icon = "audiobookshelf.svg";
              };
            }
          ];
        }
        {
          "Downloads" = [
            {
              "Radarr" = {
                href = "${nucBase}:7878";
                description = "Movies";
                icon = "radarr.svg";
              };
            }
            {
              "Sonarr" = {
                href = "${nucBase}:8989";
                description = "TV shows";
                icon = "sonarr.svg";
              };
            }
            {
              "Prowlarr" = {
                href = "${nucBase}:9696";
                description = "Indexer manager";
                icon = "prowlarr.svg";
              };
            }
          ];
        }
        {
          "Home" = [
            {
              "Home Assistant" = {
                href = "https://homeassistant.${tailnet}";
                description = "Home automation";
                icon = "home-assistant.svg";
              };
            }
            {
              "Homebridge" = {
                href = "https://homebridge.${tailnet}";
                description = "HomeKit bridge";
                icon = "homebridge.svg";
              };
            }
          ];
        }
        {
          "Monitoring" = [
            {
              "Gatus" = {
                href = "https://gatus.${tailnet}";
                description = "Status page";
                icon = "gatus.svg";
              };
            }
          ];
        }
      ];
    };

    environment.systemPackages = [ config.services.homepage-dashboard.package ];
  };
}
