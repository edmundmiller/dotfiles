# Per-agent external heartbeat monitors.
# Each monitor entry generates a systemd timer+service that pings healthchecks.io.
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

  mkHeartbeatScript =
    name: mon:
    pkgs.writeShellScript "openclaw-heartbeat-${name}" ''
      set -euo pipefail
      PING_URL="${mon.pingUrl}"

      # Signal start to healthchecks.io
      ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL/start" || true

      # Source secrets env (same as gateway) for API keys
      ENV_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openclaw/env"
      if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
      fi

      # Read gateway token
      OPENCLAW_AUTH_TOKEN="$(cat ${mon.gatewayTokenFile})"
      export OPENCLAW_AUTH_TOKEN

      # Trigger agent heartbeat — captures output for healthchecks.io
      OUTPUT=$(openclaw agent \
        --agent ${mon.agent} \
        -m "Read HEARTBEAT.md and run the diagnostic. Reply with a single status line." \
        2>&1) || {
        EXIT_CODE=$?
        echo "$OUTPUT" | ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL/fail" --data-raw @- || true
        exit $EXIT_CODE
      }

      # Signal success with agent output as body
      echo "$OUTPUT" | ${pkgs.curl}/bin/curl -sS -m 10 --retry 3 "$PING_URL" --data-raw @- || true
    '';
in
{
  options = {
    enable = mkBoolOpt false;
    interval = mkOption {
      type = types.str;
      default = "30m";
      description = "Default systemd timer interval for all monitors (overridable per-monitor)";
    };
    monitors = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            agent = mkOption {
              type = types.str;
              description = "OpenClaw agent ID to send the heartbeat message to";
            };
            pingUrl = mkOption {
              type = types.str;
              description = "healthchecks.io ping URL for this monitor";
            };
            interval = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Override timer interval for this monitor (defaults to shared interval)";
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
      description = "Per-agent heartbeat monitors. Each entry generates a systemd timer+service.";
    };
  };

  services = mkIf hbCfg.enable (
    mapAttrs' (
      name: mon:
      nameValuePair "openclaw-heartbeat-monitor-${name}" {
        Unit = {
          Description = "OpenClaw heartbeat monitor (${name})";
          After = [ "openclaw-gateway.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${mkHeartbeatScript name mon}";
          Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin";
          TimeoutStartSec = "5m";
        };
      }
    ) hbCfg.monitors
  );

  timers = mkIf hbCfg.enable (
    mapAttrs' (
      name: mon:
      nameValuePair "openclaw-heartbeat-monitor-${name}" {
        Unit.Description = "Timer for OpenClaw heartbeat monitor (${name})";
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
