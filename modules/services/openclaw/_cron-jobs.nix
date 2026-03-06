# Declarative cron job definitions for OpenClaw gateway.
# Generates a seed JSON and a merge script that preserves runtime state
# across deploys (lastRunAtMs, consecutiveErrors, etc.).
{
  cfg,
  lib,
  pkgs,
}:

with lib;
with lib.my;

let
  cronCfg = cfg.cronJobs;

  # Build a single job entry for the seed JSON
  mkJobJson = name: job: {
    inherit (job) id;
    inherit (job) agentId;
    inherit name;
    inherit (job) enabled;
    schedule =
      if job.schedule.kind == "every" then
        {
          kind = "every";
          inherit (job.schedule) everyMs;
        }
      else
        {
          kind = "cron";
          inherit (job.schedule) expr;
          inherit (job.schedule) tz;
        };
    inherit (job) sessionTarget;
    inherit (job) wakeMode;
    payload = {
      kind = "agentTurn";
      inherit (job) message;
      inherit (job) timeoutSeconds;
    }
    // optionalAttrs (job.model != null) { inherit (job) model; }
    // optionalAttrs (job.thinking != null) { inherit (job) thinking; };
    delivery =
      if job.delivery.mode == "none" then
        { mode = "none"; }
      else
        {
          inherit (job.delivery) mode channel;
          inherit (job.delivery) to;
        };
  };

  seedJobs = mapAttrsToList mkJobJson cronCfg;

  seedJson = pkgs.writeText "openclaw-cron-seed.json" (
    builtins.toJSON {
      version = 1;
      jobs = seedJobs;
    }
  );

  # Merge script: seed declarative jobs while preserving runtime state.
  # Existing jobs not in the seed are removed (fully declarative).
  mergeScript = pkgs.writeShellScript "openclaw-cron-merge" ''
    set -euo pipefail
    CRON_DIR="$HOME/.openclaw/cron"
    STORE="$CRON_DIR/jobs.json"
    SEED="${seedJson}"

    mkdir -p "$CRON_DIR"

    if [[ ! -f "$STORE" ]]; then
      cp "$SEED" "$STORE"
      exit 0
    fi

    # Merge: take declarative config from seed, preserve runtime state from existing
    ${pkgs.jq}/bin/jq -n \
      --slurpfile seed "$SEED" \
      --slurpfile old "$STORE" '
      ($old[0].jobs // []) | map({(.id): .state}) | add // {} | . as $states |
      $seed[0] | .jobs |= map(
        . + (if $states[.id] then {state: $states[.id]} else {} end)
      )
    ' > "$STORE.tmp"
    mv "$STORE.tmp" "$STORE"
  '';

in
{
  options = {
    enable = mkBoolOpt true;
  };

  inherit mergeScript;

  # Module option type for individual cron jobs
  jobType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Stable UUID for this job (prevents duplication across restarts)";
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
      };

      agentId = mkOption {
        type = types.str;
        default = "main";
      };

      schedule = {
        kind = mkOption {
          type = types.enum [
            "cron"
            "every"
          ];
          default = "cron";
        };
        expr = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Cron expression (when kind=cron)";
        };
        tz = mkOption {
          type = types.str;
          default = "America/Chicago";
        };
        everyMs = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Interval in ms (when kind=every)";
        };
      };

      sessionTarget = mkOption {
        type = types.enum [
          "isolated"
          "main"
        ];
        default = "isolated";
      };

      wakeMode = mkOption {
        type = types.str;
        default = "next-heartbeat";
      };

      message = mkOption {
        type = types.str;
        description = "Prompt message sent to the agent";
      };

      timeoutSeconds = mkOption {
        type = types.int;
        default = 300;
      };

      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override model for this job";
      };

      thinking = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Thinking mode override (low/medium/high)";
      };

      delivery = {
        mode = mkOption {
          type = types.enum [
            "none"
            "announce"
          ];
          default = "none";
        };
        channel = mkOption {
          type = types.str;
          default = "telegram";
        };
        to = mkOption {
          type = types.str;
          default = "";
          description = "Delivery target (e.g. Telegram chat ID)";
        };
      };
    };
  };
}
