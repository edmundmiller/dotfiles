# Obsidian vault sync scripts (Cubox + Snipd)
#
# Runs sync-cubox.py and sync-snipd.py as systemd user timers.
# Scripts live in the obsidian vault (synced via obsidian-sync container).
# API keys injected via agenix → systemd EnvironmentFile.
#
# Setup (one-time, after first deploy):
#   1. Create agenix secrets: cubox-api-key.age, snipd-api-key.age
#   2. Run `./scripts/sync-snipd.py auth` on a machine with a browser to get token
#   3. Encrypt the token: echo -n "TOKEN" | agenix -e snipd-api-key.age
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
  cfg = config.modules.services.vault-sync;
  user = config.user.name;
  inherit (config.user) home;
  vaultPath = "${home}/obsidian-vault";

  # Write env file from agenix secrets at service start
  mkEnvScript = pkgs.writeShellScript "vault-sync-env" ''
    set -euo pipefail
    mkdir -p "$XDG_RUNTIME_DIR/vault-sync"
    {
      echo "CUBOX_API_KEY=$(cat ${cfg.cuboxApiKeyFile})"
      echo "CUBOX_DOMAIN=${cfg.cuboxDomain}"
      echo "SNIPD_API_KEY=$(cat ${cfg.snipdApiKeyFile})"
      echo "VAULT_PATH=${vaultPath}"
    } > "$XDG_RUNTIME_DIR/vault-sync/env"
  '';
in
{
  options.modules.services.vault-sync = {
    enable = mkBoolOpt false;

    cuboxApiKeyFile = mkOption {
      type = types.str;
      description = "Path to agenix secret file containing Cubox API key";
    };

    snipdApiKeyFile = mkOption {
      type = types.str;
      description = "Path to agenix secret file containing Snipd API key";
    };

    cuboxDomain = mkOption {
      type = types.str;
      default = "cubox.cc";
      description = "Cubox domain (cubox.cc for international, cubox.pro for China)";
    };

    cuboxInterval = mkOption {
      type = types.str;
      default = "*:0/30";
      description = "Cubox sync interval (systemd OnCalendar format, default: every 30min)";
    };

    snipdInterval = mkOption {
      type = types.str;
      default = "*:0/60";
      description = "Snipd sync interval (systemd OnCalendar format, default: every 60min)";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      home-manager.users.${user} = {
        # --- Cubox sync ---
        systemd.user.services.sync-cubox = {
          Unit = {
            Description = "Sync Cubox articles to Obsidian vault";
            After = [ "network-online.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStartPre = toString mkEnvScript;
            EnvironmentFile = "-%t/vault-sync/env";
            ExecStart = "${pkgs.uv}/bin/uv run --script ${vaultPath}/scripts/sync-cubox.py";
            WorkingDirectory = vaultPath;
          };
        };

        systemd.user.timers.sync-cubox = {
          Unit.Description = "Sync Cubox articles every 30 minutes";
          Timer = {
            OnCalendar = cfg.cuboxInterval;
            RandomizedDelaySec = "2min";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        # --- Snipd sync ---
        systemd.user.services.sync-snipd = {
          Unit = {
            Description = "Sync Snipd podcast snips to Obsidian vault";
            After = [ "network-online.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStartPre = toString mkEnvScript;
            EnvironmentFile = "-%t/vault-sync/env";
            ExecStart = "${pkgs.uv}/bin/uv run --script ${vaultPath}/scripts/sync-snipd.py";
            WorkingDirectory = vaultPath;
            TimeoutStartSec = "600";
          };
        };

        systemd.user.timers.sync-snipd = {
          Unit.Description = "Sync Snipd podcast snips every hour";
          Timer = {
            OnCalendar = cfg.snipdInterval;
            RandomizedDelaySec = "5min";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    }
  );
}
