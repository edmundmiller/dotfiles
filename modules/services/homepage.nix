# Homepage Dashboard
# Tailscale: https://homepage.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8082
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "homepage", endpoint: tcp:443, tag: tag:server
# 3. Deploy: hey nuc
# 4. Approve host in admin console
{
  config,
  lib,
  pkgs,
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
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "homepage";
    };
  };

  config = mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = homepagePort;
      openFirewall = true;

      allowedHosts = concatStringsSep "," (
        [
          "localhost:${toString homepagePort}"
          "nuc.${tailnet}:${toString homepagePort}"
        ]
        ++ optionals cfg.tailscaleService.enable [
          # Tailscale serve proxies HTTPS — Host header has no port
          "${cfg.tailscaleService.serviceName}.${tailnet}"
        ]
      );

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

      bookmarks = [
        {
          "Admin" = [
            {
              "Tailscale" = [
                {
                  icon = "tailscale.svg";
                  href = "https://login.tailscale.com/admin/services/svc:homepage";
                  description = "Services admin";
                }
              ];
            }
          ];
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

    # Tailscale serve — HTTPS at https://homepage.<tailnet>
    systemd.services.homepage-tailscale-serve = mkIf cfg.tailscaleService.enable {
      description = "Tailscale serve proxy for Homepage Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "homepage-dashboard.service"
        "tailscaled.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString homepagePort} && exit 0; sleep 1; done; exit 1'";
        ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
      };
    };

    environment.systemPackages = [ config.services.homepage-dashboard.package ];
  };
}
