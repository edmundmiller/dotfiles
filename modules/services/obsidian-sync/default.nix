# Headless Obsidian Sync using obsidian-headless CLI (open beta)
#
# Setup is fully automated via 1Password when op.* options are set.
# Manual fallback: ob login → ob sync-setup → launchctl start org.nixos.obsidian-sync
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
        ".beads"
        ".claude"
        ".github"
        ".scripts"
        ".opencode"
        ".qmd"
        ".tn"
        ".config"
        ".agents"
        ".goose"
        "node_modules"
        # Old PARA folder names (pre-renumber migration)
        "01_Projects"
        "02_Areas"
        "03_Resources"
        "04_Archive"
        "05_Attachments"
        "06_Metadata"
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
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Make ob available for interactive setup (ob login, ob sync-setup)
      user.packages = [ pkgs.my.obsidian-headless ];
    }

    # Darwin (launchd agent)
    (optionalAttrs isDarwin {
      launchd.user.agents.obsidian-sync = {
        command = "${pkgs.writeShellScript "obsidian-sync-launchd" ''
          ${
            if hasOp then
              ''
                ${autoLogin} || exit 0
                ${autoSetup} || exit 0
              ''
            else
              ''
                # Exit cleanly if sync not configured (prevents restart loop)
                ${checkConfigured} || exit 0
              ''
          }
          ${configScript}
          exec ${syncScript}
        ''}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/obsidian-sync.log";
          StandardErrorPath = "/tmp/obsidian-sync.err";
        };
      };
    })

    # NixOS (systemd service)
    (optionalAttrs (!isDarwin) {
      systemd.tmpfiles.rules = [
        "d ${cfg.vaultPath} 0755 ${cfg.user} users -"
      ];

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
            ++ [ "${configScript}" ];
          ExecStart = "${syncScript}";
          Restart = "on-failure";
          RestartSec = "30s";

          # Load OP_SERVICE_ACCOUNT_TOKEN when tokenFile is configured
          EnvironmentFile = mkIf (cfg.op.tokenFile != null) "/run/obsidian-sync-op.env";

          # op CLI needs a writable dir for ~/.config/op session data.
          # PrivateTmp=true gives an isolated /tmp; redirect XDG_CONFIG_HOME there.
          Environment = mkIf (cfg.op.tokenFile != null) "XDG_CONFIG_HOME=/tmp";

          # Hardening
          ProtectHome = "read-only";
          ReadWritePaths = [ cfg.vaultPath ];
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };
    })
  ]);
}
