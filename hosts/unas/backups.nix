{ config, pkgs, ... }:
let
  restic-backup-id = "d4036fb6-5ae6-47be-9dde-937d91d430c6";
in
{
  # This runtime identity is provisioned on UNAS, never embedded in the store.
  age.identityPaths = [ "${config.users.users.emiller.home}/.ssh/id_ed25519" ];
  # Agenix runs during boot activation, before ordinary home mounts.
  fileSystems."/home/emiller".neededForBoot = true;

  services.restic.backups = {
    daily = {
      # A missing or misconfigured repository must not silently create a new one.
      initialize = false;

      rcloneConfigFile = config.age.secrets."restic/rclone".path;
      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;

      # The existing encrypted target is an rclone remote:path, not a Restic URI.
      # Add its backend at runtime without exposing the locator in the store.
      package = pkgs.writeShellScriptBin "restic" ''
        set -eu
        RESTIC_REPOSITORY="rclone:$(${pkgs.coreutils}/bin/cat "$RESTIC_REPOSITORY_FILE")"
        export RESTIC_REPOSITORY
        unset RESTIC_REPOSITORY_FILE
        exec ${pkgs.restic}/bin/restic "$@"
      '';
      extraOptions = [ "rclone.program=${pkgs.rclone}/bin/rclone" ];

      user = "emiller";
      paths = [
        "${config.users.users.emiller.home}/sync"
        "${config.users.users.emiller.home}/archive"
        "/data/docs"
      ];

      # Keep historical backups during recovery. Review retention separately.
      pruneOpts = [ ];

      backupPrepareCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/start";
      backupCleanupCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/$EXIT_STATUS";
    };
  };

  systemd.services.restic-backups-daily.unitConfig.RequiresMountsFor = [
    config.users.users.emiller.home
    "/data/docs"
  ];
}
