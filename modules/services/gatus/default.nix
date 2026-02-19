# Gatus - Automated service uptime monitoring
# Tailscale: https://gatus.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8084
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "gatus", endpoint: tcp:443, tag: tag:server
# 3. Deploy: hey nuc
# 4. Approve host in admin console
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.gatus;
  gatusPort = cfg.port;

  configFile = pkgs.writeText "gatus-config.yaml" (
    builtins.toJSON {
      web.port = gatusPort;

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      endpoints = [
        {
          name = "Home Assistant";
          group = "Smart Home";
          url = "http://localhost:8123/api/";
          interval = "60s";
          conditions = [
            "[STATUS] < 500"
          ];
        }
        {
          name = "Homebridge";
          group = "Smart Home";
          url = "http://localhost:8581";
          interval = "60s";
          conditions = [
            "[STATUS] < 500"
          ];
        }
        {
          name = "Matter Server";
          group = "Smart Home";
          url = "tcp://localhost:5580";
          interval = "120s";
          conditions = [
            "[CONNECTED] == true"
          ];
        }
        {
          name = "Jellyfin";
          group = "Media";
          url = "http://localhost:8096/health";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "Sonarr";
          group = "Media";
          url = "http://localhost:8989/ping";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "Radarr";
          group = "Media";
          url = "http://localhost:7878/ping";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "Prowlarr";
          group = "Media";
          url = "http://localhost:9696/ping";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "PostgreSQL";
          group = "Infrastructure";
          url = "tcp://localhost:5432";
          interval = "60s";
          conditions = [
            "[CONNECTED] == true"
          ];
        }
        {
          name = "Tailscale";
          group = "Infrastructure";
          url = "http://localhost:41112/healthz";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
      ]
      ++ optionals config.modules.services.openclaw.enable [
        {
          name = "OpenClaw Gateway";
          group = "Infrastructure";
          url = "http://localhost:18789";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
      ]
      ++ optionals config.modules.services.audiobookshelf.enable [
        {
          name = "Audiobookshelf";
          group = "Media";
          url = "http://localhost:13378/healthcheck";
          interval = "60s";
          conditions = [
            "[STATUS] == 200"
          ];
        }
      ];
    }
  );
in
{
  options.modules.services.gatus = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 8084;

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "gatus";
    };
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      systemd.services.gatus = {
        description = "Gatus uptime monitor";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          StateDirectory = "gatus";
          ExecStart = "${pkgs.gatus}/bin/gatus";
          Environment = [ "GATUS_CONFIG_PATH=${configFile}" ];
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ gatusPort ];

      systemd.services.gatus-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Gatus";
        wantedBy = [ "multi-user.target" ];
        after = [
          "gatus.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString gatusPort} && exit 0; sleep 1; done; exit 1'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
