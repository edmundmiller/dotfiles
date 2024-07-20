{
  config,
  pkgs,
  ...
}: let
  restic-backup-id = "96db4aad6dac4ac48bf8c066122a7ecf";
  monitor-key = "restic-sync";
in {
  services.restic.backups = {
    daily = {
      initialize = true;

      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;

      user = "emiller";
      paths = [
        "${config.users.users.emiller.home}/sync"
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

      backupPrepareCommand = "${pkgs.curl}/bin/curl -m 5 --retry 5 https://cronitor.link/p/${restic-backup-id}/${monitor-key}?state=run&host=$HOST";
      backupCleanupCommand = "${pkgs.curl}/bin/curl -m 5 --retry 5 https://cronitor.link/p/${restic-backup-id}/${monitor-key}?state=\${$EXIT_STATUS:+fail}\${$EXIT_STATUS:-complete}&status_code=$EXIT_STATUS&host=$HOST";
    };
  };
}
