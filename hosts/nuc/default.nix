# Go nuc yourself
{pkgs, ...}: {
  imports = [
    ../server.nix
    ../home.nix
    ./hardware-configuration.nix
    ./disko.nix
  ];

  ## Modules
  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    hardware = {
      bluetooth.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services = {
      docker.enable = true;
      hass.enable = true;
      qb.enable = false;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };

    theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

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
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };
}
