# AgentsView PostgreSQL dashboard
# Tailscale: https://agentsview.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8087
#
# Setup (one-time):
# 1. Create/update svc:agentsview in ~/src/personal/tailnet via Tailscale API
# 2. Add svc:agentsview to tailscale/policy.hujson explicit service grant
# 3. Apply tailnet ACL with OpenTofu
# 4. Deploy: hey nuc
#
# PostgreSQL sync is one-way: local SQLite → PostgreSQL. Each machine that
# creates sessions must run `agentsview pg push`; this service only serves the
# shared read-only dashboard from PostgreSQL.
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
  cfg = config.modules.services.agentsview;
  tailnet = "cinnamon-rooster.ts.net";
  publicUrl = "https://${cfg.tailscaleService.serviceName}.${tailnet}";
  stateHome = "/var/lib/agentsview";
  configDir = "${stateHome}/.agentsview";
  configFile = "${configDir}/config.toml";
  pgUrl = "postgresql:///agentsview?host=/run/postgresql&user=${cfg.postgresUser}&sslmode=disable";

  configTemplate = pkgs.writeText "agentsview-config.toml.template" ''
    require_auth = ${if cfg.requireAuth then "true" else "false"}
    auth_token = "__AUTH_TOKEN__"
    public_url = "${publicUrl}"
    public_origins = ["${publicUrl}"]

    [pg]
    url = "${pgUrl}"
    machine_name = "${cfg.machineName}"
    schema = "${cfg.schema}"
    allow_insecure = false
  '';

  prepareConfig = pkgs.writeShellScript "agentsview-prepare-config" ''
    set -euo pipefail

    install -d -m 0700 '${configDir}'

    if [ -f '${configFile}' ]; then
      auth_token="$(${pkgs.gnused}/bin/sed -n 's/^auth_token *= *"\(.*\)"/\1/p' '${configFile}' | head -n1)"
    else
      auth_token=""
    fi

    if [ -z "$auth_token" ]; then
      auth_token="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
    fi

    cp '${configTemplate}' '${configFile}'
    AUTH_TOKEN="$auth_token" ${pkgs.perl}/bin/perl -0pi -e 's/__AUTH_TOKEN__/$ENV{AUTH_TOKEN}/g' '${configFile}'

    chmod 0600 '${configFile}'
  '';
in
{
  options.modules.services.agentsview = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 8087;
    host = mkOpt types.str "127.0.0.1";
    machineName = mkOpt types.str "nuc";
    schema = mkOpt types.str "agentsview";
    requireAuth = mkBoolOpt true;
    postgresUser = mkOpt types.str "agentsview";

    tailscaleService = {
      enable = mkBoolOpt true;
      serviceName = mkOpt types.str "agentsview";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      assertions = [
        {
          assertion = cfg.requireAuth || cfg.host == "127.0.0.1" || cfg.host == "localhost";
          message = "AgentsView must keep requireAuth enabled when binding to a non-loopback address.";
        }
      ];

      user.packages = [ pkgs.llm-agents.agentsview ];

      users.groups.agentsview = { };
      users.users.agentsview = {
        isSystemUser = true;
        group = "agentsview";
        home = stateHome;
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "agentsview" ];
        ensureUsers = [
          {
            name = cfg.postgresUser;
            ensureDBOwnership = true;
          }
        ];
        # Cross-machine sync should use an SSH tunnel to 127.0.0.1:5432 on the
        # NUC rather than exposing PostgreSQL on tailscale0. The tunnel is
        # authenticated by SSH; this pg_hba rule lets `agentsview pg push` use
        # the dedicated low-privilege role without putting a DB password in
        # every workstation's config file.
        authentication = mkAfter ''
          host agentsview ${cfg.postgresUser} 127.0.0.1/32 trust
          host agentsview ${cfg.postgresUser} ::1/128 trust
        '';
      };

      systemd.tmpfiles.rules = [
        "d ${stateHome} 0700 agentsview agentsview -"
        "d ${configDir} 0700 agentsview agentsview -"
      ];

      systemd.services.agentsview-pg = {
        description = "AgentsView PostgreSQL dashboard";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "postgresql.service"
        ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          User = "agentsview";
          Group = "agentsview";
          StateDirectory = "agentsview";
          StateDirectoryMode = "0700";
          ExecStartPre = prepareConfig;
          ExecStart = concatStringsSep " " [
            "${pkgs.llm-agents.agentsview}/bin/agentsview"
            "pg"
            "serve"
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--public-url"
            publicUrl
          ];
          Environment = [
            "HOME=${stateHome}"
            "AGENTSVIEW_PG_URL=${pgUrl}"
            "AGENTSVIEW_PG_MACHINE=${cfg.machineName}"
            "AGENTSVIEW_PG_SCHEMA=${cfg.schema}"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

      systemd.services.agentsview-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for AgentsView";
        wantedBy = [ "multi-user.target" ];
        after = [
          "agentsview-pg.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
