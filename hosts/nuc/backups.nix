{ config, pkgs, ... }:
let
  restic-backup-id = "c351536f-39a4-4725-9d92-04fcb26b6306";
in
{
  services.restic.backups = {
    daily = {
      initialize = true;

      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;

      user = "root";
      paths = [
        "${config.users.users.emiller.home}/sync"
        "${config.users.users.emiller.home}/obsidian-vault"
        # "${config.users.users.emiller.home}/archive"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];

      exclude = [
        "*/.stversions"
        "*/.git"
      ];

      backupPrepareCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/start";
      backupCleanupCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/$EXIT_STATUS";
    };
  };
}
