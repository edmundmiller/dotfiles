{
  config,
  pkgs,
  ...
}: let
  restic-backups-gdrive-sync-backup-id = "bfae5213-4fd4-4700-86e5-3ad6f9a7f62e";
  restic-backups-B2-sync-backup-id = "422804e7-53c3-4d8b-b02b-2816b1bf3905";
  restic-backups-B2-archive-backup-id = "b0f29a55-12d3-4f87-a081-5564a223b4d5";
  restic-backups-B2-paperless-backup-id = "7661bacf-5d2e-495b-8874-47adfdae86b2";
in {
  services.restic.backups = {
    daily = {
      initialize = true;

      environmentFile = config.age.secrets."restic/env".path;
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
      preStart = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-gdrive-sync-backup-id}/start";
      postStop = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/${restic-backups-gdrive-sync-backup-id}/$EXIT_STATUS";
    };
  };
}
