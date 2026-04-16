# Mission Control - AI agent orchestration dashboard
# Tailscale: https://mission-control.<tailnet>.ts.net
# Local (host-only): http://127.0.0.1:3005
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "mission-control", endpoint: tcp:443, tag: tag:server
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
  cfg = config.modules.services.mission-control;
  agentsJson = pkgs.writeText "mission-control-agents.json" (builtins.toJSON cfg.registeredAgents);
  containerService = "${config.virtualisation.oci-containers.backend}-mission-control.service";
  syncScript = pkgs.writeShellScript "mission-control-sync-agents" ''
        set -euo pipefail

        if [ ! -f ${lib.escapeShellArg (toString cfg.environmentFile)} ]; then
          echo "mission-control env file missing: ${toString cfg.environmentFile}" >&2
          exit 1
        fi

        api_key="$(${pkgs.gnugrep}/bin/grep '^API_KEY=' ${lib.escapeShellArg (toString cfg.environmentFile)} \
          | ${pkgs.coreutils}/bin/head -n1 \
          | ${pkgs.gnused}/bin/sed 's/^API_KEY=//')"

        if [ -z "$api_key" ]; then
          echo "mission-control API_KEY missing from ${toString cfg.environmentFile}" >&2
          exit 1
        fi

        for _ in $(seq 1 60); do
          if ${pkgs.curl}/bin/curl -fsS http://127.0.0.1:${toString cfg.port}/login >/dev/null; then
            break
          fi
          sleep 2
        done

        export MC_SYNC_API_KEY="$api_key"
        export MC_SYNC_URL="http://127.0.0.1:${toString cfg.port}/api/agents/register"
        export MC_SYNC_AGENTS_JSON=${lib.escapeShellArg agentsJson}

        ${pkgs.python3}/bin/python3 <<'PY'
    import json
    import os
    import sys
    import urllib.request

    api_key = os.environ["MC_SYNC_API_KEY"]
    url = os.environ["MC_SYNC_URL"]
    with open(os.environ["MC_SYNC_AGENTS_JSON"], "r", encoding="utf-8") as fh:
        agents = json.load(fh)

    for agent in agents:
        data = json.dumps(agent).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
                "x-api-key": api_key,
            },
            method="POST",
        )
        with urllib.request.urlopen(request) as response:
            if response.status >= 400:
                raise RuntimeError(f"Mission Control agent registration failed for {agent['name']}: {response.status}")
    PY
  '';
in
{
  options.modules.services.mission-control = {
    enable = mkBoolOpt false;
    image = mkOpt types.str "ghcr.io/builderz-labs/mission-control:latest";
    port = mkOpt types.port 3005;
    environmentFile = mkOpt (types.nullOr types.path) null;
    agentSourceDir = mkOpt (types.nullOr types.path) null;
    registeredAgents = mkOpt (types.listOf (
      types.submodule {
        options = {
          name = mkOpt types.str "";
          role = mkOpt types.str "assistant";
          framework = mkOpt types.str "hermes";
          capabilities = mkOpt (types.listOf types.str) [ ];
        };
      }
    )) [ ];

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "mission-control";
    };
  };

  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.environmentFile != null;
          message = "modules.services.mission-control.environmentFile must be set.";
        }
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/mission-control 0750 1001 1001 -"
      ];

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

      virtualisation.oci-containers.containers.mission-control = {
        autoStart = true;
        inherit (cfg) image;
        ports = [ "127.0.0.1:${toString cfg.port}:3000" ];
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          HOME = "/home/nextjs";
          NODE_ENV = "production";
          PORT = "3000";
          NEXT_PUBLIC_GATEWAY_OPTIONAL = "true";
        };
        volumes = [
          "/var/lib/mission-control:/app/.data"
        ]
        ++ optionals (cfg.agentSourceDir != null) [
          "${cfg.agentSourceDir}:/home/nextjs/.agents:ro"
        ];
        extraOptions = [
          "--pull=always"
          "--mount=type=tmpfs,destination=/app/.next/cache"
        ];
      };

      systemd.services.${containerService} = {
        serviceConfig = {
          RestartSec = mkForce "10s";
        };
      };

      systemd.services.mission-control-sync-agents = mkIf (cfg.registeredAgents != [ ]) {
        description = "Sync local Hermes agent definitions into Mission Control";
        wantedBy = [ "multi-user.target" ];
        after = [ containerService ];
        wants = [ containerService ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = syncScript;
        };
      };

      systemd.services.mission-control-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Mission Control";
        wantedBy = [ "multi-user.target" ];
        after = [
          containerService
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
