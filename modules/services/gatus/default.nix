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

  # Alerting config — only include enabled providers
  alertingConfig =
    { }
    // optionalAttrs cfg.alerting.telegram.enable {
      telegram = {
        token = "__TELEGRAM_TOKEN__";
        id = cfg.alerting.telegram.chatId;
        default-alert = {
          enabled = true;
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };
    };

  # Default alert list per endpoint — one entry per enabled provider
  endpointAlerts =
    [ ]
    ++ optionals cfg.alerting.telegram.enable [
      { type = "telegram"; }
    ];

  # Helper to add alerts to an endpoint
  withAlerts =
    ep:
    ep
    // optionalAttrs (endpointAlerts != [ ]) {
      alerts = endpointAlerts;
    };

  configTemplate = pkgs.writeText "gatus-config-template.yaml" (
    builtins.toJSON (
      {
        web.port = gatusPort;

        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
        };

        endpoints = map withAlerts (
          [
            {
              name = "Home Assistant";
              group = "Smart Home";
              url = "http://localhost:8123/api/";
              interval = "60s";
              conditions = [ "[STATUS] < 500" ];
            }
            {
              name = "Homebridge";
              group = "Smart Home";
              url = "http://localhost:8581";
              interval = "60s";
              conditions = [ "[STATUS] < 500" ];
            }
            {
              name = "Matter Server";
              group = "Smart Home";
              url = "tcp://localhost:5580";
              interval = "120s";
              conditions = [ "[CONNECTED] == true" ];
            }
            {
              name = "Jellyfin";
              group = "Media";
              url = "http://localhost:8096/health";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            {
              name = "Sonarr";
              group = "Media";
              url = "http://localhost:8989/ping";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            {
              name = "Radarr";
              group = "Media";
              url = "http://localhost:7878/ping";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            {
              name = "Prowlarr";
              group = "Media";
              url = "http://localhost:9696/ping";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            {
              name = "PostgreSQL";
              group = "Infrastructure";
              url = "tcp://localhost:5432";
              interval = "60s";
              conditions = [ "[CONNECTED] == true" ];
            }
            {
              name = "Tailscale";
              group = "Infrastructure";
              url = "http://localhost:41112/healthz";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
          ]
          ++ optionals config.modules.services.openclaw.enable [
            {
              name = "OpenClaw Gateway";
              group = "Infrastructure";
              url = "http://localhost:18789";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
          ]
          ++ optionals config.modules.services.audiobookshelf.enable [
            {
              name = "Audiobookshelf";
              group = "Media";
              url = "http://localhost:13378/healthcheck";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
          ]
        );
      }
      // optionalAttrs (alertingConfig != { }) {
        alerting = alertingConfig;
      }
    )
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

    alerting.telegram = {
      enable = mkBoolOpt false;
      botTokenFile = mkOpt types.str "";
      chatId = mkOpt types.str "";
    };

    healthcheck = {
      enable = mkBoolOpt false;
      pingUrl = mkOpt types.str "";
      interval = mkOpt types.str "2min";
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
          RuntimeDirectory = "gatus";
          # '+' prefix runs as root to read agenix secrets, then chowns to DynamicUser
          ExecStartPre =
            "+"
            + pkgs.writeShellScript "gatus-prepare-config" (
              ''
                cp ${configTemplate} /run/gatus/config.yaml
              ''
              + optionalString cfg.alerting.telegram.enable ''
                TELEGRAM_TOKEN=$(cat ${cfg.alerting.telegram.botTokenFile})
                ${pkgs.gnused}/bin/sed -i "s|__TELEGRAM_TOKEN__|$TELEGRAM_TOKEN|g" /run/gatus/config.yaml
              ''
              + ''
                # RuntimeDirectory is owned by DynamicUser; match ownership
                chown "$(stat -c %u /run/gatus)" /run/gatus/config.yaml
                chmod 600 /run/gatus/config.yaml
              ''
            );
          ExecStart = "${pkgs.gatus}/bin/gatus";
          Environment = [ "GATUS_CONFIG_PATH=/run/gatus/config.yaml" ];
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ gatusPort ];

      # Dead man's switch — pings healthchecks.io to prove Gatus is alive
      systemd.services.gatus-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Ping healthchecks.io dead man's switch";
        after = [ "gatus.service" ];
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          ExecStart = "${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}";
        };
      };

      systemd.timers.gatus-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Ping healthchecks.io on schedule";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = cfg.healthcheck.interval;
          RandomizedDelaySec = "10s";
        };
      };

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
