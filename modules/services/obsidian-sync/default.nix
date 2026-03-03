# Headless Obsidian Sync using obsidian-headless CLI (open beta)
#
# One-time setup:
#   1. ob login                (interactive — needs terminal)
#   2. ob sync-setup --vault "<vault-name>" --path <vaultPath>
#   3. systemctl start obsidian-sync
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

  configScript = pkgs.writeShellScript "obsidian-sync-config" ''
    ${ob} sync-config \
      --path ${escapeShellArg cfg.vaultPath} \
      --mode ${syncMode} \
      --device-name ${escapeShellArg cfg.deviceName}
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

    deviceName = mkOpt types.str config.networking.hostName;

    continuous = mkBoolOpt true;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Make ob available for interactive setup (ob login, ob sync-setup)
      user.packages = [ pkgs.my.obsidian-headless ];
    }

    # NixOS-only (systemd service)
    (optionalAttrs (!isDarwin) {
      systemd.tmpfiles.rules = [
        "d ${cfg.vaultPath} 0755 ${cfg.user} users -"
      ];

      systemd.services.obsidian-sync = {
        description = "Obsidian Headless Sync";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = "users";
          ExecStartPre = "${configScript}";
          ExecStart = "${syncScript}";
          Restart = "on-failure";
          RestartSec = "30s";

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
