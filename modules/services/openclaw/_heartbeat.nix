# External gateway liveness probe.
# Generates systemd timer+service that checks gateway health and pings healthchecks.io.
# Complements the native in-process heartbeat (which handles session-aware monitoring).
{
  cfg,
  lib,
  pkgs,
  user,
}:

with lib;
with lib.my;

let
  hbCfg = cfg.heartbeatMonitor;

  mkHealthScript =
    name: mon:
    pkgs.writeShellScript "openclaw-liveness-${name}" ''
      set -euo pipefail
      PING_URL="${mon.pingUrl}"

      # Signal start to healthchecks.io
      ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL/start" || true

      # Source secrets env (same as gateway) for auth token
      ENV_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openclaw/env"
      if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
      fi

      # Read gateway token (needed for health check CLI)
      OPENCLAW_AUTH_TOKEN="$(cat ${mon.gatewayTokenFile})"
      export OPENCLAW_AUTH_TOKEN

      # Gateway health check — deterministic, no LLM call, exits non-zero if unreachable
      OUTPUT=$(openclaw health --json --timeout ${toString mon.timeout} 2>&1) || {
        EXIT_CODE=$?
        echo "$OUTPUT" | ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL/fail" --data-raw @- || true
        exit $EXIT_CODE
      }

      # Signal success with health snapshot as body
      echo "$OUTPUT" | ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL" --data-raw @- || true
    '';
in
{
  options = {
    enable = mkBoolOpt false;
    interval = mkOption {
      type = types.str;
      default = "2h";
      description = "Default systemd timer interval (native heartbeat handles frequent checks)";
    };
    monitors = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            pingUrl = mkOption {
              type = types.str;
              description = "healthchecks.io ping URL for this monitor";
            };
            interval = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Override timer interval for this monitor (defaults to shared interval)";
            };
            timeout = mkOption {
              type = types.int;
              default = 10000;
              description = "Health check timeout in ms (default 10s)";
            };
            gatewayTokenFile = mkOption {
              type = types.str;
              default = cfg.gatewayTokenFile;
              description = "Path to gateway auth token (defaults to main gatewayTokenFile)";
            };
          };
        }
      );
      default = { };
      description = "Gateway liveness monitors. Each entry generates a systemd timer+service.";
    };
  };

  services = mkIf hbCfg.enable (
    mapAttrs' (
      name: mon:
      nameValuePair "openclaw-heartbeat-monitor-${name}" {
        Unit = {
          Description = "OpenClaw gateway liveness probe (${name})";
          After = [ "openclaw-gateway.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${mkHealthScript name mon}";
          Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin";
          TimeoutStartSec = "60";
        };
      }
    ) hbCfg.monitors
  );

  timers = mkIf hbCfg.enable (
    mapAttrs' (
      name: mon:
      nameValuePair "openclaw-heartbeat-monitor-${name}" {
        Unit.Description = "Timer for OpenClaw gateway liveness probe (${name})";
        Timer = {
          OnBootSec = "5m";
          OnUnitActiveSec = if mon.interval != null then mon.interval else hbCfg.interval;
          RandomizedDelaySec = "2m";
        };
        Install.WantedBy = [ "timers.target" ];
      }
    ) hbCfg.monitors
  );
}
