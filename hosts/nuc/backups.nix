{ config, pkgs, ... }:
let
  restic-backup-id = "c351536f-39a4-4725-9d92-04fcb26b6306";
  hermesProfileHomes = map (
    profile: "${config.services.hermes-agent.profiles.${profile}.stateDir}/.hermes"
  ) (builtins.attrNames config.services.hermes-agent.profiles);

  commonBackupOptions = {
    initialize = true;

    user = "root";

    pruneOpts = [
      "--keep-within 24h"
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
  hermesProfileRestic = pkgs.writeShellApplication {
    name = "hermes-profile-restic";
    runtimeInputs = [ pkgs.restic ];
    excludeShellChecks = [ "SC1091" ];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "hermes-profile-restic must run as root; retry with sudo" >&2
        exit 1
      fi
      set -a
      . ${config.age.secrets."restic/nuc-r2-env".path}
      set +a
      exec restic "$@"
    '';
  };
in
{
  environment.systemPackages = [ hermesProfileRestic ];

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

    music-assistant-state = nucR2Backup // {
      paths = [ "/var/lib/music-assistant" ];
      timerConfig = {
        OnCalendar = "*-*-* 00:45:00";
        RandomizedDelaySec = "15m";
      };
    };

    # Preserve runtime-installed skills, config edits, sessions, databases, and
    # other mutable profile state. Canonical config still belongs in
    # agents-workspace; these snapshots provide rollback and diff evidence for
    # changes made by or through a running Hermes agent between deployments.
    hermes-profile-state = nucR2Backup // {
      paths = hermesProfileHomes;
      extraBackupArgs = [
        "--tag"
        "hermes-profile-state"
      ];
      timerConfig = {
        OnCalendar = "*-*-* *:15:00";
        RandomizedDelaySec = "10m";
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
    homebox-state = nucR2Backup // {
      paths = [ "/var/lib/homebox" ];
      extraBackupArgs = [
        "--tag"
        "homebox-state"
      ];
      pruneOpts = [ ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
        RandomizedDelaySec = "15m";
      };
      backupPrepareCommand = "${pkgs.systemd}/bin/systemctl stop homebox.service";
      backupCleanupCommand = "${pkgs.systemd}/bin/systemctl start homebox.service";
    };
    sparkyfitness-state = nucR2Backup // {
      paths = [ "/var/lib/sparkyfitness" ];
      extraBackupArgs = [
        "--tag"
        "sparkyfitness-state"
      ];
      pruneOpts = [ ];
      timerConfig = {
        OnCalendar = "*-*-* 02:30:00";
        RandomizedDelaySec = "15m";
      };
      backupPrepareCommand = "${pkgs.systemd}/bin/systemctl stop sparkyfitness.service";
      backupCleanupCommand = "${pkgs.systemd}/bin/systemctl start sparkyfitness.service sparkyfitness-tailscale-serve.service";
    };
  };
}
