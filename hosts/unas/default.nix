# No u nas

{ lib, pkgs, ... }: {
  imports =
    [ ../home.nix ./hardware-configuration.nix ./backups.nix ./nas.nix ];

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
      k3s.enable = true;
      minio.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };
  };

  time.timeZone = "America/Chicago";

  users.users.mmiller = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIO/gdHAayVgaF1Vmm2RKe+Ign2I4Ue3cbt2HTD/POm9 monicadd4@gmail.com"
    ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = {
          dataset = "datatank/backup/unas";
          presend =
            "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893/start";
          postsend =
            "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };
}
