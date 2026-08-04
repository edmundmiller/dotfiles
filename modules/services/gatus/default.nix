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
  obsidianSyncHealthcheckId =
    if config.modules.services.obsidian-sync.healthcheck.pingUrl != "" then
      last (splitString "/" config.modules.services.obsidian-sync.healthcheck.pingUrl)
    else
      "";

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
  endpointAlerts = optionals cfg.alerting.telegram.enable [
    { type = "telegram"; }
  ];

  # Helper to add alerts to an endpoint
  withAlerts =
    ep:
    ep
    // optionalAttrs (endpointAlerts != [ ]) {
      alerts = endpointAlerts;
    };

  # Endpoints contributed by the services themselves via
  # `modules.services.<name>.registry.gatus`. Adding a monitored service is a
  # one-line change in that service's own module, not an edit here.
  #
  # Sub-services count too: `hass.homebridge` has its own `enable` and its own
  # registry, so it is gated on that flag rather than on its parent's.
  registryContributors =
    let
      isContributor = v: builtins.isAttrs v && v ? registry && v ? enable;
      children = svc: filter isContributor (attrValues (removeAttrs svc [ "registry" ]));
      collect = svc: [ svc ] ++ children svc;
    in
    concatMap collect (filter isContributor (attrValues config.modules.services));

  # Sort the whole endpoint list by `order` (then name) and drop `order`, which
  # is display metadata rather than Gatus config.
  sortEndpoints =
    endpoints:
    map (entry: removeAttrs entry [ "order" ]) (
      sort (a: b: if a.order != b.order then a.order < b.order else a.name < b.name) endpoints
    );

  registryEndpoints = concatMap (
    svc:
    let
      entry = svc.registry.gatus;
    in
    optional (svc.enable && entry != null) (
      (removeAttrs entry [
        "alerts"
        "headers"
      ])
      // optionalAttrs (entry.headers != { }) { inherit (entry) headers; }
      // optionalAttrs (entry.alerts && endpointAlerts != [ ]) { alerts = endpointAlerts; }
    )
  ) registryContributors;

  configTemplate = pkgs.writeText "gatus-config-template.yaml" (
    builtins.toJSON (
      {
        web.port = gatusPort;

        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
        };

        # Every endpoint carries an `order`; the combined list is sorted once and
        # `order` stripped, so registry-contributed entries land in the same
        # positions they occupied when they were hard-coded here.
        endpoints = sortEndpoints (
          (map withAlerts [
            {
              name = "Matter Server";
              order = 30;
              group = "Smart Home";
              url = "tcp://localhost:5580";
              interval = "120s";
              conditions = [ "[CONNECTED] == true" ];
            }
            {
              name = "PostgreSQL";
              order = 80;
              group = "Infrastructure";
              url = "tcp://localhost:5432";
              interval = "60s";
              conditions = [ "[CONNECTED] == true" ];
            }
            {
              name = "Mill Docs Agents";
              order = 90;
              group = "Infrastructure";
              url = "https://mill-docs-agents.cinnamon-rooster.ts.net/";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            {
              name = "Grafana Cloud";
              order = 100;
              group = "Monitoring";
              url = "https://fearlesslorry169.grafana.net/api/health";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
            # TODO: Tailscale local API doesn't expose healthz on 41112
            # {
            #   name = "Tailscale";
            #   group = "Infrastructure";
            #   url = "http://localhost:41112/healthz";
            #   interval = "60s";
            #   conditions = [ "[STATUS] == 200" ];
            # }
          ])
          ++ optionals config.modules.services.homepage.enable [
            {
              name = "Homepage";
              order = 130;
              group = "Monitoring";
              url = "http://localhost:8082";
              interval = "60s";
              conditions = [ "[STATUS] == 200" ];
            }
          ]
          ++
            optionals
              (
                config.modules.services.obsidian-sync.enable
                && config.modules.services.obsidian-sync.healthcheck.enable
                && cfg.healthchecks.readonlyApiKeyFile != ""
                && obsidianSyncHealthcheckId != ""
              )
              [
                {
                  name = "Obsidian Sync";
                  order = 140;
                  group = "Sync";
                  url = "https://healthchecks.io/api/v2/checks/${obsidianSyncHealthcheckId}";
                  headers = {
                    X-Api-Key = "__HEALTHCHECKS_API_KEY__";
                  };
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY].status == up"
                  ];
                }
              ]
          ++ registryEndpoints
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

    healthchecks.readonlyApiKeyFile = mkOpt types.str "";
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
              + optionalString (cfg.healthchecks.readonlyApiKeyFile != "") ''
                HEALTHCHECKS_API_KEY=$(cat ${cfg.healthchecks.readonlyApiKeyFile})
                ${pkgs.gnused}/bin/sed -i "s|__HEALTHCHECKS_API_KEY__|$HEALTHCHECKS_API_KEY|g" /run/gatus/config.yaml
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

      # Dead man's switch — checks Gatus is healthy, then reports to healthchecks.io
      systemd.services.gatus-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Check Gatus health and ping healthchecks.io";
        after = [ "gatus.service" ];
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          # Signal start (- prefix: ignore curl failure so main command still runs)
          ExecStartPre = "-${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/start";
          # Main check: verify Gatus is responding
          ExecStart = "${pkgs.curl}/bin/curl -fsS -m 10 http://localhost:${toString gatusPort}/health";
          # Report exit status to healthchecks.io (0=success, >0=failure)
          ExecStopPost = "${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/\${EXIT_STATUS}";
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
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString gatusPort} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
