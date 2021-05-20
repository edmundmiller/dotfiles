# No u nas

{ lib, pkgs, ... }: {
  imports = [ ../home.nix ./hardware-configuration.nix ./nas.nix ];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services = {
      docker.enable = true;
      jellyfin.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
    };
  };

  time.timeZone = "America/Chicago";

  users.users.moni = { isNormalUser = true; };

  systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = {
          dataset = "datatank/backup/unas";
          postsend =
            "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };

  services.restic.backups = {
    localsyncbackup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = [ "/home/emiller/sync" ];
      repository = "/data/backup/emiller/sync";
      user = "emiller";
    };
    localarchivebackup = {
      initialize = true;
      passwordFile = "/home/emiller/.secrets/restic";
      paths = [ "/home/emiller/archive" ];
      repository = "/data/backup/emiller/archive";
      user = "emiller";
      timerConfig.OnCalendar = "monthly";
    };
  };
}
