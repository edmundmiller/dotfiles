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
    # environmentFile should contain HOMEPAGE_VAR_* entries, e.g.:
    #   HOMEPAGE_VAR_HASS_TOKEN=...
    #   HOMEPAGE_VAR_HOMEBRIDGE_PASSWORD=...
    #   HOMEPAGE_VAR_JELLYFIN_API_KEY=...
    #   HOMEPAGE_VAR_NEXTDNS_PROFILE=...
    #   HOMEPAGE_VAR_NEXTDNS_API_KEY=...
    #   HOMEPAGE_VAR_TAILSCALE_DEVICE_ID=...
    #   HOMEPAGE_VAR_TAILSCALE_API_KEY=...
    #   HOMEPAGE_VAR_LUBELOGGER_USERNAME=...
    #   HOMEPAGE_VAR_LUBELOGGER_PASSWORD=...
    environmentFile = mkOpt (types.nullOr types.path) null;
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

      environmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;

      widgets = [
        { logo = { }; }
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
                # widget = {
                #   type = "jellyfin";
                #   url = "http://localhost:8096";
                #   key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
                #   version = 2;
                #   enableBlocks = true;
                # };
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
                widget = {
                  type = "homeassistant";
                  url = "http://localhost:8123";
                  key = "{{HOMEPAGE_VAR_HASS_TOKEN}}";
                };
              };
            }
            {
              "Homebridge" = {
                href = "https://homebridge.${tailnet}";
                description = "HomeKit bridge";
                icon = "homebridge.svg";
                widget = {
                  type = "homebridge";
                  url = "http://localhost:8581";
                  username = "admin";
                  password = "{{HOMEPAGE_VAR_HOMEBRIDGE_PASSWORD}}";
                };
              };
            }
            {
              "LubeLogger" = {
                href = "${nucBase}:5000";
                description = "Vehicle maintenance tracker";
                icon = "lubelogger.svg";
                widget = {
                  type = "lubelogger";
                  url = "http://localhost:5000";
                  username = "{{HOMEPAGE_VAR_LUBELOGGER_USERNAME}}";
                  password = "{{HOMEPAGE_VAR_LUBELOGGER_PASSWORD}}";
                };
              };
            }
          ];
        }
        {
          "Network" = [
            {
              "NextDNS" = {
                href = "https://my.nextdns.io";
                description = "DNS filtering";
                icon = "nextdns.svg";
                widget = {
                  type = "nextdns";
                  profile = "{{HOMEPAGE_VAR_NEXTDNS_PROFILE}}";
                  key = "{{HOMEPAGE_VAR_NEXTDNS_API_KEY}}";
                };
              };
            }
            {
              "Tailscale" = {
                href = "https://login.tailscale.com/admin";
                description = "VPN mesh";
                icon = "tailscale.svg";
                widget = {
                  type = "tailscale";
                  deviceid = "{{HOMEPAGE_VAR_TAILSCALE_DEVICE_ID}}";
                  key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                };
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
                widget = {
                  type = "gatus";
                  url = "http://localhost:8084";
                };
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
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString homepagePort} && exit 0; sleep 1; done; exit 1\"'";
        ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
      };
    };

    environment.systemPackages = [ config.services.homepage-dashboard.package ];
  };
}
