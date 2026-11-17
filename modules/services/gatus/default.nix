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

  defaultAlert = {
    enabled = true;
    failure-threshold = 3;
    success-threshold = 2;
    send-on-resolved = true;
  };

  # Alerting config — only include enabled providers
  alertingConfig =
    { }
    // optionalAttrs cfg.alerting.telegram.enable {
      telegram = {
        token = "__TELEGRAM_TOKEN__";
        id = cfg.alerting.telegram.chatId;
        default-alert = defaultAlert;
      };
    }
    // optionalAttrs (cfg.alerting.notion.enable || cfg.alerting.email.enable) {
      custom = {
        url = "http://127.0.0.1:${
          toString (if cfg.alerting.notion.enable then cfg.alerting.notion.port else cfg.alerting.email.port)
        }/events";
        method = "POST";
        headers = {
          Content-Type = "application/json";
        };
        default-alert = defaultAlert;
      };
    };

  incidentAlert = route: ep: {
    type = "custom";
    # Gatus checksums omit provider overrides. Keep stable, distinct route IDs.
    description = "gatus-${route}";
    durable-delivery = true;
    provider-override = {
      url = "http://127.0.0.1:${toString cfg.alerting.${route}.port}/events";
      headers = {
        Content-Type = "application/json";
        Authorization = "Bearer __${route}_INGEST_TOKEN__";
      };
      # Encode names at build time; Gatus does not JSON-escape placeholders.
      body = builtins.toJSON {
        endpoint = "${ep.group}: ${ep.name}";
        state = "[ALERT_TRIGGERED_OR_RESOLVED]";
      };
    };
  };

  # Preserve Telegram's existing opt-in scope. The new routes default to HA only.
  alertsFor =
    ep:
    optionals cfg.alerting.telegram.enable [ { type = "telegram"; } ]
    ++ optionals (elem ep.name cfg.alerting.endpoints) (
      optional cfg.alerting.email.enable (incidentAlert "email" ep)
      ++ optional cfg.alerting.notion.enable (incidentAlert "notion" ep)
    );

  # Helper to add alerts to an endpoint
  withAlerts =
    ep:
    let
      alerts = alertsFor ep;
    in
    ep
    // optionalAttrs (alerts != [ ]) {
      inherit alerts;
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
      endpoint =
        (removeAttrs entry [
          "alerts"
          "headers"
        ])
        // optionalAttrs (entry.headers != { }) { inherit (entry) headers; };
    in
    optional (svc.enable && entry != null) (if entry.alerts then withAlerts endpoint else endpoint)
  ) registryContributors;

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
    ++ optional cfg.alerting.notion.enable {
      name = "Notion Incident Delivery";
      group = "Monitoring";
      order = 110;
      url = "http://127.0.0.1:${toString cfg.alerting.notion.port}/health";
      interval = "60s";
      conditions = [ "[STATUS] == 200" ];
      # Delivery health is dashboard-only; the mail receiver permits HA only.
    }
    ++ optional cfg.alerting.email.enable {
      name = "Email Incident Delivery";
      group = "Monitoring";
      order = 111;
      url = "http://127.0.0.1:${toString cfg.alerting.email.port}/health";
      interval = "60s";
      conditions = [ "[STATUS] == 200" ];
    }
  );

  configTemplate = pkgs.writeText "gatus-config-template.yaml" (
    builtins.toJSON (
      {
        web.port = gatusPort;
        inherit endpoints;
        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
          # Keep at least 24 hours of one-minute HA runtime probes/events.
          maximum-number-of-results = 1500;
          maximum-number-of-events = 1500;
        };
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

    alerting.endpoints = mkOpt (types.listOf types.str) [ "Home Assistant Runtime" ];

    alerting.email = {
      enable = mkBoolOpt false;
      port = mkOpt types.port 8126;
      url = mkOpt types.str "";
      tokenFile = mkOpt types.str "";
      ingestTokenFile = mkOpt types.str "";
    };

    alerting.notion = {
      enable = mkBoolOpt false;
      port = mkOpt types.port 8125;
      tokenFile = mkOpt types.str "";
      ingestTokenFile = mkOpt types.str "";
      dataSourceId = mkOpt types.str "";
      evidenceUrl = mkOpt types.str "";
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
      assertions = [
        {
          assertion =
            !cfg.alerting.email.enable
            || (
              cfg.alerting.email.tokenFile != ""
              && cfg.alerting.email.ingestTokenFile != ""
              && hasPrefix "https://" cfg.alerting.email.url
              && cfg.alerting.email.port != cfg.port
              && cfg.alerting.email.port != cfg.alerting.notion.port
              && cfg.alerting.endpoints == [ "Home Assistant Runtime" ]
            );
          message = "Gatus Cloudflare email requires scoped runtime API/ingest tokens, HTTPS URL, a distinct local port and HA Runtime-only scope.";
        }
        {
          assertion =
            !cfg.alerting.notion.enable
            || (
              all (value: value != "") [
                cfg.alerting.notion.tokenFile
                cfg.alerting.notion.ingestTokenFile
                cfg.alerting.notion.dataSourceId
              ]
              && hasPrefix "https://" cfg.alerting.notion.evidenceUrl
              && cfg.alerting.notion.port != cfg.port
            );
          message = "Gatus Notion requires runtime API/ingest token files, a data source, HTTPS evidence URL and a distinct local port.";
        }
      ];

      systemd.services.gatus = {
        description = "Gatus uptime monitor";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "tailscaled.service"
        ]
        ++ optional cfg.alerting.notion.enable "gatus-notion.service"
        ++ optional cfg.alerting.email.enable "gatus-email.service";
        wants =
          optional cfg.alerting.notion.enable "gatus-notion.service"
          ++ optional cfg.alerting.email.enable "gatus-email.service";

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
                set -eu
                install -m 600 ${configTemplate} /run/gatus/config.yaml
              ''
              + optionalString cfg.alerting.telegram.enable ''
                TELEGRAM_TOKEN=$(cat ${cfg.alerting.telegram.botTokenFile})
                ${pkgs.gnused}/bin/sed -i "s|__TELEGRAM_TOKEN__|$TELEGRAM_TOKEN|g" /run/gatus/config.yaml
              ''
              + optionalString (cfg.healthchecks.readonlyApiKeyFile != "") ''
                HEALTHCHECKS_API_KEY=$(cat ${cfg.healthchecks.readonlyApiKeyFile})
                ${pkgs.gnused}/bin/sed -i "s|__HEALTHCHECKS_API_KEY__|$HEALTHCHECKS_API_KEY|g" /run/gatus/config.yaml
              ''
              + optionalString (cfg.alerting.email.enable || cfg.alerting.notion.enable) ''
                ${pkgs.python3}/bin/python3 - <<'PY'
                import json
                from pathlib import Path
                path = Path("/run/gatus/config.yaml")
                config = json.loads(path.read_text())
                tokens = {}
                ${concatMapStrings
                  (
                    route:
                    optionalString cfg.alerting.${route}.enable ''
                      tokens["__${route}_INGEST_TOKEN__"] = Path(${
                        builtins.toJSON cfg.alerting.${route}.ingestTokenFile
                      }).read_text().strip()
                    ''
                  )
                  [
                    "email"
                    "notion"
                  ]
                }
                if not all(tokens.values()):
                    raise SystemExit("Gatus incident ingest token is empty")
                for endpoint in config["endpoints"]:
                    for alert in endpoint.get("alerts", []):
                        headers = alert.get("provider-override", {}).get("headers", {})
                        for placeholder, token in tokens.items():
                            if placeholder in headers.get("Authorization", ""):
                                headers["Authorization"] = "Bearer " + token
                path.write_text(json.dumps(config))
                PY
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

      systemd.services.gatus-notion = mkIf cfg.alerting.notion.enable {
        description = "Deliver Gatus incidents to Notion";
        wantedBy = [ "multi-user.target" ];
        # Start the local queue even when the upstream network is unavailable.
        after = [ "network.target" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "gatus-notion";
          StateDirectoryMode = "0700";
          UMask = "0077";
          LoadCredential = [
            "notion-token:${cfg.alerting.notion.tokenFile}"
            "ingest-token:${cfg.alerting.notion.ingestTokenFile}"
          ];
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = concatStringsSep " " [
            "${pkgs.python3}/bin/python3"
            "${./incident-delivery.py}"
            "--state-file /var/lib/gatus-notion/incidents.sqlite"
            "--token-file %d/notion-token"
            "--ingest-token-file %d/ingest-token"
            "--port ${toString cfg.alerting.notion.port}"
            "--data-source ${escapeShellArg cfg.alerting.notion.dataSourceId}"
            "--evidence-url ${escapeShellArg cfg.alerting.notion.evidenceUrl}"
            "--endpoints-file ${
              pkgs.writeText "gatus-notion-endpoints.json" (
                builtins.toJSON (
                  map (ep: "${ep.group}: ${ep.name}") (
                    filter (ep: elem ep.name cfg.alerting.endpoints && (ep.alerts or [ ]) != [ ]) endpoints
                  )
                )
              )
            }"
          ];
        };
      };

      systemd.services.gatus-email = mkIf cfg.alerting.email.enable {
        description = "Deliver ordered Gatus email transitions through Family Ops";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "gatus-email";
          StateDirectoryMode = "0700";
          UMask = "0077";
          LoadCredential = [
            "email-token:${cfg.alerting.email.tokenFile}"
            "ingest-token:${cfg.alerting.email.ingestTokenFile}"
          ];
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = concatStringsSep " " [
            "${pkgs.python3}/bin/python3"
            "${./incident-delivery.py}"
            "--state-file /var/lib/gatus-email/events.sqlite"
            "--token-file %d/email-token"
            "--ingest-token-file %d/ingest-token"
            "--port ${toString cfg.alerting.email.port}"
            "--email-url ${escapeShellArg cfg.alerting.email.url}"
            "--endpoints-file ${
              pkgs.writeText "gatus-email-endpoints.json" (
                builtins.toJSON [ "Smart Home: Home Assistant Runtime" ]
              )
            }"
          ];
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
