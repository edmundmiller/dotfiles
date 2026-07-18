# Headless Obsidian Sync using obsidian-headless CLI (open beta)
#
# Setup is fully automated via 1Password when op.* options are set.
# Manual fallback: ob login → ob sync-setup → systemctl start obsidian-sync
#
# Modes:
#   server  — pull-only (default). Keeps a read-only local copy.
#   desktop — bidirectional. Full two-way sync for editing.
#
# WARNING: Do NOT use headless sync AND the Obsidian desktop app on the same device.
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
  cfg = config.modules.services.obsidian-sync;

  ob = "${pkgs.my.obsidian-headless}/bin/ob";

  syncMode =
    if cfg.syncMode != null then
      cfg.syncMode
    else if cfg.mode == "server" then
      "pull-only"
    else
      "bidirectional";

  excludedFoldersStr = concatStringsSep "," cfg.excludedFolders;

  safetyCheck = pkgs.writeShellScript "obsidian-sync-safety-check" ''
    set -eu
    state_dir=${escapeShellArg (dirOf cfg.safety.statePath)}
    mkdir -p "$state_dir"
    events="$state_dir/events.jsonl"
    ${pkgs.systemd}/bin/journalctl -u obsidian-sync.service --since "6 minutes ago" -o json --no-pager > "$events"
    exec ${pkgs.bun}/bin/bun ${escapeShellArg cfg.safety.checkerPath} \
      --vault ${escapeShellArg cfg.vaultPath} \
      --policy ${escapeShellArg cfg.safety.policyPath} \
      --engine headless \
      --excluded-folders ${escapeShellArg excludedFoldersStr} \
      --event-log "$events" \
      --state ${escapeShellArg cfg.safety.statePath} \
      --json
  '';

  safetyStop = pkgs.writeShellScript "obsidian-sync-safety-stop" ''
    set -u
    if ${pkgs.util-linux}/bin/runuser -u ${escapeShellArg cfg.user} -- ${safetyCheck}; then
      exit 0
    else
      rc=$?
    fi
    ${pkgs.systemd}/bin/systemctl stop obsidian-sync.service || true
    ${optionalString (cfg.healthcheck.enable && cfg.healthcheck.pingUrl != "")
      "${pkgs.curl}/bin/curl -fsS -m 10 ${escapeShellArg "${cfg.healthcheck.pingUrl}/fail"} >/dev/null || true"
    }
    echo "Obsidian Sync stopped by corruption tripwire" >&2
    exit "$rc"
  '';

  configScript = pkgs.writeShellScript "obsidian-sync-config" ''
    ${ob} sync-config \
      --path ${escapeShellArg cfg.vaultPath} \
      --mode ${syncMode} \
      --device-name ${escapeShellArg cfg.deviceName} \
      ${optionalString (
        cfg.excludedFolders != [ ]
      ) "--excluded-folders ${escapeShellArg excludedFoldersStr}"}
  '';

  hasOp =
    cfg.op.emailRef != ""
    && cfg.op.passwordRef != ""
    && cfg.op.itemRef != ""
    && cfg.op.encryptionPasswordRef != "";

  op = "${pkgs._1password-cli}/bin/op";

  # Login via 1Password if not already logged in
  autoLogin = pkgs.writeShellScript "obsidian-sync-login" ''
    if ${ob} login 2>&1 | grep -q "Logged in"; then
      echo "Already logged in"
      exit 0
    fi
    echo "Logging in via 1Password..."
    ${ob} login \
      --email "$(${op} read ${escapeShellArg cfg.op.emailRef})" \
      --password "$(${op} read ${escapeShellArg cfg.op.passwordRef})" \
      --mfa "$(
        ref=${escapeShellArg cfg.op.itemRef}
        if [[ "$ref" == op://* ]]; then
          vault=$(echo "$ref" | sed 's|op://||' | cut -d/ -f1)
          item=$(echo "$ref" | sed 's|op://||' | cut -d/ -f2)
          ${op} item get "$item" --vault "$vault" --otp
        else
          ${op} item get "$ref" --otp
        fi
      )"
  '';

  # Run sync-setup via 1Password if not already configured
  autoSetup = pkgs.writeShellScript "obsidian-sync-setup" ''
    if ${ob} sync-list-local 2>/dev/null | grep -q ${escapeShellArg cfg.vaultPath}; then
      echo "Vault already configured"
      exit 0
    fi
    echo "Running sync-setup via 1Password..."
    ${ob} sync-setup \
      --vault ${escapeShellArg cfg.vaultName} \
      --path ${escapeShellArg cfg.vaultPath} \
      --password "$(${op} read ${escapeShellArg cfg.op.encryptionPasswordRef})" \
      --device-name ${escapeShellArg cfg.deviceName}
  '';

  # Check if sync-setup has been run (vault is configured)
  checkConfigured = pkgs.writeShellScript "obsidian-sync-check" ''
    if ! ${ob} sync-list-local 2>/dev/null | grep -q ${escapeShellArg cfg.vaultPath}; then
      echo "No sync configuration found for ${cfg.vaultPath}" >&2
      echo "Run 'ob sync-setup' first." >&2
      exit 1
    fi
  '';

  syncScript = pkgs.writeShellScript "obsidian-sync-start" ''
    # ob doesn't clean up .sync.lock on kill/crash; remove stale lock before starting
    rm -rf ${escapeShellArg cfg.vaultPath}/.obsidian/.sync.lock
    exec ${ob} sync \
      --path ${escapeShellArg cfg.vaultPath} \
      ${optionalString cfg.continuous "--continuous"}
  '';
in
{
  options.modules.services.obsidian-sync = {
    enable = mkBoolOpt false;

    vaultPath = mkOpt types.str "${config.users.users.${config.user.name}.home}/obsidian-vault";

    user = mkOpt types.str config.user.name;

    mode = mkOption {
      type = types.enum [
        "server"
        "desktop"
      ];
      default = "server";
      description = ''
        server  = pull-only (read-only local copy).
        desktop = bidirectional (full two-way sync).
      '';
    };

    syncMode = mkOption {
      type = types.nullOr (
        types.enum [
          "bidirectional"
          "pull-only"
          "mirror-remote"
        ]
      );
      default = null;
      description = ''
        Override sync mode. Defaults to pull-only for server, bidirectional for desktop.
        mirror-remote = pull-only + revert any local changes.
      '';
    };

    deviceName = mkOpt types.str (if isDarwin then "mac" else config.networking.hostName);

    excludedFolders = mkOption {
      type = types.listOf types.str;
      default = [
        # Agent/dev dirs
        ".git"
        ".agent"
        ".beads"
        ".claude"
        ".codex"
        ".env"
        ".envrc"
        ".flue"
        ".github"
        ".scripts"
        ".opencode"
        ".pi"
        ".qmd"
        ".tn"
        ".config"
        ".agents"
        ".goose"
        ".hooks"
        ".moss"
        ".pytest_cache"
        ".scripts"
        ".tmp"
        "node_modules"
        "TaskNotes"
        "OLD_VAULT"
        ".mdbase"
        ".amp"
        "scripts"
        ".trash"
        "01_Projects"
        "02_Areas"
        "03_Resources"
        "04_Archive"
        "05_Attachments"
        "06_Archive"
        "06_Metadata"
        "02_Projects/Eve-Healthcheck-Remediator-Spike/node_modules"
        ".obsidian/plugins-disabled-20260505-160148"
        ".obsidian/plugins-disabled-20260505-162506"
        ".obsidian/plugins-disabled-all-20260505-164607"
        ".obsidian/quarantine-resynced-corrupt-title-files-20260506-082607"
        ".obsidian/quarantine-resynced-corrupt-title-files-20260506-082626"
        "06_Attachments/YouTube"
        "src"
        "dist"
        "rule-tests"
        "rules"
        "test"
        "vendor"
        "worker"
        "workflows"
      ];
      description = "Folders to exclude from sync.";
    };

    continuous = mkBoolOpt true;

    vaultName = mkOpt types.str "vault";

    op = {
      emailRef = mkOpt types.str "";
      passwordRef = mkOpt types.str "";
      itemRef = mkOpt types.str "";
      encryptionPasswordRef = mkOpt types.str "";
      # Path to a file containing a raw 1Password service account token.
      # When set, a oneshot service generates /run/obsidian-sync-op.env
      # (KEY=VALUE format) so the service can call `op` unattended.
      tokenFile = mkOpt (types.nullOr types.str) null;
    };

    healthcheck = {
      enable = mkBoolOpt false;
      pingUrl = mkOpt types.str "";
      interval = mkOpt types.str "2min";
    };

    safety = {
      enable = mkBoolOpt true;
      checkerPath = mkOpt types.str "${cfg.vaultPath}/scripts/obsidian-sync-safety-check.ts";
      policyPath = mkOpt types.str "${cfg.vaultPath}/07_Metadata/Validation/obsidian-sync-policy.json";
      statePath = mkOpt types.str "/var/lib/obsidian-sync-guard/state.json";
      interval = mkOpt types.str "30s";
      fullySyncedMaxAge = mkOpt types.str "3 minutes";
    };
  };

  config = mkIf cfg.enable (
    {
      # Make ob available for interactive setup (ob login, ob sync-setup)
      user.packages = [ pkgs.my.obsidian-headless ];
    }
    // optionalAttrs (!isDarwin) {
      systemd.tmpfiles.rules = [
        "d ${cfg.vaultPath} 0755 ${cfg.user} users -"
      ]
      ++ optional cfg.safety.enable "d ${dirOf cfg.safety.statePath} 0750 ${cfg.user} users -";

      # Generate /run/obsidian-sync-op.env from the raw token file so
      # systemd EnvironmentFile (which needs KEY=VALUE format) can load it.
      systemd.services.obsidian-sync-op-env = mkIf (cfg.op.tokenFile != null) {
        description = "Generate obsidian-sync OP env file";
        before = [ "obsidian-sync.service" ];
        requiredBy = [ "obsidian-sync.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "obsidian-sync-op-env" ''
            printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' "$(cat ${cfg.op.tokenFile})" \
              > /run/obsidian-sync-op.env
            chmod 600 /run/obsidian-sync-op.env
          '';
        };
      };

      systemd.services.obsidian-sync = {
        description = "Obsidian Headless Sync";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = "users";
          ExecStartPre =
            (
              if hasOp then
                [
                  "${autoLogin}"
                  "${autoSetup}"
                ]
              else
                [ "${checkConfigured}" ]
            )
            ++ [ "${configScript}" ]
            ++ optional cfg.safety.enable "${safetyCheck}";
          ExecStart = "${syncScript}";
          Restart = "on-failure";
          RestartSec = "30s";

          # Load OP_SERVICE_ACCOUNT_TOKEN when tokenFile is configured
          EnvironmentFile = mkIf (cfg.op.tokenFile != null) "/run/obsidian-sync-op.env";

          # op CLI and obsidian-headless both use XDG config under the
          # service user's home. Keep those persistent; putting
          # XDG_CONFIG_HOME in PrivateTmp makes ob forget login/vault setup on
          # every restart.

          # Hardening
          ProtectHome = "read-only";
          ReadWritePaths = [
            cfg.vaultPath
            "${config.users.users.${cfg.user}.home}/.config/op"
            "${config.users.users.${cfg.user}.home}/.config/obsidian-headless"
          ];
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };

      systemd.services.obsidian-sync-guard = mkIf cfg.safety.enable {
        description = "Stop Obsidian Sync when corruption tripwires fire";
        after = [ "obsidian-sync.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${safetyStop}";
        };
      };

      systemd.timers.obsidian-sync-guard = mkIf cfg.safety.enable {
        description = "Run Obsidian Sync corruption tripwires";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.safety.interval;
          OnUnitActiveSec = cfg.safety.interval;
          AccuracySec = "1s";
        };
      };

      # Dead man's switch — verifies service is active + vault has files, pings healthchecks.io
      systemd.services.obsidian-sync-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Check obsidian-sync health and ping healthchecks.io";
        after = [ "obsidian-sync.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "-${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/start";
          ExecStart = pkgs.writeShellScript "obsidian-sync-healthcheck" ''
            ${optionalString cfg.safety.enable "${pkgs.util-linux}/bin/runuser -u ${escapeShellArg cfg.user} -- ${safetyCheck}"}
            # Verify systemd service is active
            ${pkgs.systemd}/bin/systemctl is-active --quiet obsidian-sync.service || {
              echo "obsidian-sync.service is not active" >&2
              exit 1
            }
            # Verify vault directory exists and has files
            if [ ! -d ${escapeShellArg cfg.vaultPath} ] || [ -z "$(ls -A ${escapeShellArg cfg.vaultPath})" ]; then
              echo "vault directory missing or empty: ${cfg.vaultPath}" >&2
              exit 1
            fi
            if ! ${pkgs.systemd}/bin/journalctl -u obsidian-sync.service --since ${escapeShellArg "${cfg.safety.fullySyncedMaxAge} ago"} --no-pager \
              | ${pkgs.gnugrep}/bin/grep -q "Fully synced"; then
              echo "no recent Fully synced message" >&2
              exit 1
            fi
            echo "healthy: guard clean, service active, vault has files, recent Fully synced"
          '';
          ExecStopPost = "${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/\${EXIT_STATUS}";
        };
      };

      systemd.timers.obsidian-sync-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Ping healthchecks.io for obsidian-sync on schedule";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = cfg.healthcheck.interval;
          RandomizedDelaySec = "10s";
        };
      };
    }
  );
}
