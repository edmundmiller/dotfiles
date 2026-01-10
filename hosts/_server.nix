# hosts/server.nix
#
# Only to be used for headless servers, at home or abroad, with more
# security/automation-minded configuration.
{
  lib,
  pkgs,
  config,
  ...
}:
{
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_hardened;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 21d";
  };

  systemd = {
    services.clear-log = {
      description = "Clear >1 month-old logs every week";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/journalctl --vacuum-time=21d";
      };
    };
    timers.clear-log = {
      wantedBy = [ "timers.target" ];
      partOf = [ "clear-log.service" ];
      timerConfig.OnCalendar = "weekly UTC";
    };
  };

  # HACK https://github.com/danth/stylix/issues/200
  # Disabled for headless servers to avoid dconf/GTK dependencies
  # stylix.image = ../modules/themes/functional/config/wallpaper.png;

  # https://discourse.nixos.org/t/deployment-tools-evaluating-nixops-deploy-rs-and-vanilla-nix-rebuild/36388/12?u=emiller88
  system.autoUpgrade.enable = true;
  system.autoUpgrade.flake = "github:edmundmiller/dotfiles#${config.networking.hostName}";
  system.autoUpgrade.flags = [ "--refresh" ];
  system.autoUpgrade.randomizedDelaySec = "5m";
}
