{
  config,
  lib,
  pkgs,
  ...
}: let
  restic-backups-local-sync-backup-id = "09ae3517-b710-4a3e-ae68-16fe45f3697f";
  restic-backups-local-archive-backup-id = "773d889a-0ee4-42f7-98c8-7a106874a116";
  restic-backups-gdrive-sync-backup-id = "bfae5213-4fd4-4700-86e5-3ad6f9a7f62e";
  restic-backups-B2-sync-backup-id = "422804e7-53c3-4d8b-b02b-2816b1bf3905";
  restic-backups-B2-archive-backup-id = "b0f29a55-12d3-4f87-a081-5564a223b4d5";
  restic-backups-B2-paperless-backup-id = "7661bacf-5d2e-495b-8874-47adfdae86b2";
in {
  services.restic.backups = {
    # local-sync-backup = {
    #   initialize = true;
    #   passwordFile = "/home/emiller/.secrets/restic";
    #   paths = [ "/home/emiller/sync" ];
    #   repository = "/data/backup/emiller/sync";
    #   user = "emiller";
    #   timerConfig = {
    #     OnBootSec = "10min";
    #     OnUnitActiveSec = "1d";
    #   };
    # };
    # local-archive-backup = {
    #   initialize = true;
    #   passwordFile = "/home/emiller/.secrets/restic";
    #   paths = [ "/home/emiller/archive" ];
    #   repository = "/data/backup/emiller/archive";
    #   user = "emiller";
    #   timerConfig = {
    #     OnBootSec = "10min";
    #     OnUnitActiveSec = "1d";
    #   };
    # };
    gdrive-sync-backup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = ["/home/emiller/sync"];
      repository = "rclone:gdrive:/sync";
      user = "emiller";
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1d";
      };
    };
    B2-sync-backup = {
      initialize = true;
      package = pkgs.unstable.restic;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = ["/home/emiller/sync"];
      repository = "rclone:B2:sync-restic/";
      user = "emiller";
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1d";
      };
    };
    B2-archive-backup = {
      initialize = true;
      package = pkgs.unstable.restic;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = ["/data/minio/archive"];
      repository = "rclone:B2:archive-restic/";
      user = "emiller";
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1d";
      };
    };
    B2-paperless-backup = {
      initialize = true;
      package = pkgs.unstable.restic;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = ["/data/media/docs/paperless/media/documents/archive"];
      repository = "rclone:B2:restic-b2-backups/paperless";
      user = "emiller";
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1d";
      };
    };
  };

  # TODO Generalize
  # systemd.services.restic-backups-local-sync-backup = {
  #   preStart =
  #     "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-local-sync-backup-id}/start";
  #   postStop =
  #     "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-local-sync-backup-id}/$EXIT_STATUS";
  # };

  # systemd.services.restic-backups-local-archive-backup = {
  #   preStart =
  #     "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-local-archive-backup-id}/start";
  #   postStop =
  #     "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-local-archive-backup-id}/$EXIT_STATUS";
  # };

  systemd.services.restic-backups-gdrive-sync-backup = {
    preStart = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-gdrive-sync-backup-id}/start";
    postStop = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-gdrive-sync-backup-id}/$EXIT_STATUS";
  };

  systemd.services.restic-backups-B2-sync-backup = {
    preStart = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-sync-backup-id}/start";
    postStop = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-sync-backup-id}/$EXIT_STATUS";
  };

  systemd.services.restic-backups-B2-archive-backup = {
    preStart = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-archive-backup-id}/start";
    postStop = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-archive-backup-id}/$EXIT_STATUS";
  };

  systemd.services.restic-backups-B2-paperless-backup = {
    preStart = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-paperless-backup-id}/start";
    postStop = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-B2-paperless-backup-id}/$EXIT_STATUS";
  };
}
