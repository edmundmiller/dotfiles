{
  config,
  lib,
  pkgs,
  ...
}:
let
  restic-backup-id = "d4036fb6-5ae6-47be-9dde-937d91d430c6";
  replication-healthcheck = "https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
  systemVolume = {
    snapshot_dir = "@snapshots";
    subvolume = {
      "@root" = { };
      "@home" = { };
      "@var" = { };
    };
  };
  snapshotPolicy = {
    backend = "btrfs-progs";
    snapshot_preserve_min = "2d";
    snapshot_preserve = "24h 31d 12m";
  };
in
{
  fileSystems."/preservation" = {
    device = "/dev/disk/by-uuid/54707ada-4621-45f8-8626-a7690bd54e3f";
    fsType = "btrfs";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
      "compress=zstd:1"
      "noatime"
      "nodev"
      "nosuid"
    ];
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/data"
      "/preservation"
    ];
  };

  # NVMe snapshots continue even when either HDD filesystem is unavailable.
  services.btrbk.instances.unas-local = {
    onCalendar = "hourly";
    snapshotOnly = true;
    settings = snapshotPolicy // {
      volume."/.btrfs" = systemVolume;
    };
  };

  services.btrbk.instances.unas = {
    onCalendar = "hourly";
    settings = snapshotPolicy // {
      target_preserve_min = "2d";
      target_preserve = "24h 31d 12m";
      volume."/.btrfs" = systemVolume // {
        snapshot_create = "no";
        target = {
          "/data/backup/btrbk/unas" = { };
          "/preservation/btrbk/unas" = { };
        };
      };
      volume."/.btrfs-bulk" = {
        snapshot_dir = "@snapshots";
        target = "/preservation/btrbk/docs";
        subvolume."@docs" = { };
      };
    };
  };

  systemd.services.btrbk-unas-local = {
    unitConfig.RequiresMountsFor = [ "/.btrfs" ];
    serviceConfig = {
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
    };
  };

  systemd.services.btrbk-unas = {
    requires = [
      "unas-bulk-ready.service"
      "btrbk-unas-local.service"
      "preservation.mount"
    ];
    after = [
      "unas-bulk-ready.service"
      "btrbk-unas-local.service"
      "preservation.mount"
    ];
    bindsTo = [
      "unas-bulk-ready.service"
      "preservation.mount"
    ];
    unitConfig.RequiresMountsFor = [
      "/.btrfs"
      "/preservation"
    ];
    serviceConfig = {
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
    };
    preStart = ''
      actual=$(${pkgs.util-linux}/bin/findmnt --noheadings --raw --mountpoint /preservation --output UUID,FSTYPE,FSROOT)
      test "$actual" = '54707ada-4621-45f8-8626-a7690bd54e3f btrfs /'
      ${pkgs.coreutils}/bin/install -d -m 0700 /data/backup/btrbk/unas
      ${pkgs.coreutils}/bin/install -d -m 0700 /preservation/btrbk/{unas,docs}
      ${pkgs.curl}/bin/curl -fsS -m 10 --retry 2 ${replication-healthcheck}/start || true
    '';
    # A failed mount dependency also alerts through the missing success heartbeat.
    postStop = ''
      if [ "$SERVICE_RESULT" = success ]; then
        ${pkgs.curl}/bin/curl -fsS -m 10 --retry 2 ${replication-healthcheck} || true
      else
        ${pkgs.curl}/bin/curl -fsS -m 10 --retry 2 ${replication-healthcheck}/fail || true
      fi
    '';
  };

  systemd.services.restic-backups-daily = {
    requires = [ "unas-bulk-ready.service" ];
    after = [ "unas-bulk-ready.service" ];
    bindsTo = [ "unas-bulk-ready.service" ];
  };

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
