{ config, pkgs, ... }:
let
  restic-backup-id = "c351536f-39a4-4725-9d92-04fcb26b6306";

  commonBackupOptions = {
    initialize = true;

    user = "root";

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];

    exclude = [
      "*/.stversions"
      "*/.git"
    ];
  };

  nucR2Backup = commonBackupOptions // {
    environmentFile = config.age.secrets."restic/nuc-r2-env".path;
  };
in
{
  services.restic.backups = {
    daily = nucR2Backup // {
      paths = [
        "${config.users.users.emiller.home}/sync"
        "${config.users.users.emiller.home}/obsidian-vault"
        # "${config.users.users.emiller.home}/archive"
        "/var/lib/hass" # Home Assistant config + database
      ];

      backupPrepareCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/start";
      backupCleanupCommand = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backup-id}/$EXIT_STATUS";
    };

    # Audiobookshelf application state is small once transient metadata/tmp files
    # are excluded: config, SQLite DB, library metadata, covers, and cache that is
    # useful for disaster recovery without duplicating in-progress temp imports.
    audiobookshelf-state = nucR2Backup // {
      paths = [ "/var/lib/audiobookshelf" ];
      exclude = commonBackupOptions.exclude ++ [
        "/var/lib/audiobookshelf/metadata/tmp"
        "/var/lib/audiobookshelf/metadata/tmp/**"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 00:30:00";
        RandomizedDelaySec = "15m";
      };
    };

    # Audiobook media is much larger than the default 10G BorgBase restic quota,
    # so it goes to a dedicated Cloudflare R2 restic repository via restic's S3
    # backend. Do not point audiobook media at BorgBase.
    audiobooks = commonBackupOptions // {
      environmentFile = config.age.secrets."restic/audiobooks-r2-env".path;
      paths = [ "/audiobooks" ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
        RandomizedDelaySec = "30m";
      };
    };
  };
}
