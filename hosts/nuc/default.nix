# Go nuc yourself
{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    taskwarrior3
  ];
  imports = [
    ../server.nix
    ../home.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./backups.nix
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
      bugwarrior.enable = false;
      git.enable = true;
      zsh.enable = true;
      taskwarrior = {
        enable = true;
        syncUrl = "http://localhost:8080";
        shortcuts.enable = false;
        timewarriorHook.enable = false;
      };
    };
    services = {
      audiobookshelf.enable = true;
      docker.enable = true;
      hass.enable = false;
      homepage.enable = true;
      jellyfin.enable = true;
      prowlarr.enable = true;
      qb.enable = false;
      radarr.enable = true;
      sonarr.enable = true;
      ssh.enable = true;
      syncthing.enable = false;
      tailscale.enable = true;
      taskchampion.enable = true;
      obsidian-sync.enable = true;
      openportal.enable = true;
      timew_sync.enable = true;
      transmission.enable = false;
      obsidian-sync.enable = true;
    };

    # theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  users.users.emiller.hashedPasswordFile = config.age.secrets.emiller_password.path;

  # systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    # FIXME
    enable = false;
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
