{
  config,
  pkgs,
  ...
}: let
  restic-backup-id = "d4036fb6-5ae6-47be-9dde-937d91d430c6";
in {
  services.restic.backups = {
    daily = {
      initialize = true;

      rcloneConfigFile = config.age.secrets."restic/rclone".path;
      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;

      user = "emiller";
      paths = [
        "${config.users.users.emiller.home}/sync"
        "${config.users.users.emiller.home}/archive"
        "/data/media/docs/paperless/media/documents/archive"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];

      backupPrepareCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/start";
      backupCleanupCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/$EXIT_STATUS";
    };
  };
}
