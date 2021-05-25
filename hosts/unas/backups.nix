{ config, lib, pkgs, ... }:

{
  services.restic.backups = {
    local-sync-backup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = [ "/home/emiller/sync" ];
      repository = "/data/backup/emiller/sync";
      user = "emiller";
    };
    local-archive-backup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = [ "/home/emiller/archive" ];
      repository = "/data/backup/emiller/archive";
      user = "emiller";
    };
    gdrive-sync-backup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = [ "/home/emiller/sync" ];
      repository = "rclone:gdrive:/sync";
      user = "emiller";
    };
  };

  systemd.user.services.restic-backups-local-sync-backup.postStop =
    "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/09ae3517-b710-4a3e-ae68-16fe45f3697f";

  systemd.user.services.restic-backups-local-archive-backup.postStop =
    "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/773d889a-0ee4-42f7-98c8-7a106874a116";

  systemd.user.services.restic-backups-gdrive-sync-backup.postStop =
    "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/bfae5213-4fd4-4700-86e5-3ad6f9a7f62e";
}