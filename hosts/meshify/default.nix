{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix

    ## Desktop/shell environment
    <modules/desktop/bspwm.nix>

    <modules/browser/firefox.nix>
    <modules/base.nix> # FIXME
    <modules/dev/default.nix> # TODO consider individual imports
    <modules/editors/emacs.nix>
    <modules/editors/vim.nix>
    <modules/gaming/steam.nix>

    <modules/shell/pass.nix>
    <modules/shell/mail.nix>

    <modules/graphics.nix>
    <modules/music.nix> # playing music

    ## Services
    <modules/services/docker.nix>
    <modules/services/jellyfin.nix>
    <modules/services/keybase.nix>
    <modules/services/pia.nix>
    <modules/services/ssh.nix>
    <modules/services/syncthing.nix>
    <modules/services/transmission.nix>

    <modules/desktop/autorandr/meshify.nix> # FIXME

    ## Services
    <modules/services/syncthing.nix>
    ## Theme
    <themes/middle-earth>
  ];

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  # ZFS
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.grub.copyKernels = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "rpool/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = { dataset = "bigdata/backup"; };
      };
    };
  };
}
