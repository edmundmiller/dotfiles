{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix
    ## Desktop/shell environment
    <modules/desktop/bspwm.nix>
    ## Apps
    <modules/browser/firefox.nix>
    # <modules/browser/surf.nix>
    <modules/chat.nix>
    <modules/dev/cc.nix>
    <modules/dev/clojure.nix>
    <modules/dev/elm.nix>
    <modules/dev/haskell.nix>
    <modules/dev/nix.nix>
    <modules/dev/node.nix>
    <modules/dev/python.nix>
    <modules/dev/R.nix>
    <modules/dev/rust.nix>
    <modules/dev/zsh.nix>
    <modules/editors/emacs.nix>
    <modules/editors/vim.nix>
    <modules/gaming/steam.nix>
    <modules/shell/direnv.nix>
    <modules/shell/git.nix>
    <modules/shell/gnupg.nix>
    <modules/shell/ncmpcpp.nix>
    # FIXME <modules/shell/mail.nix>
    <modules/shell/pass.nix>
    <modules/shell/tmux.nix>
    <modules/shell/zsh.nix>
    ## Project-based
    <modules/music.nix> # playing music
    <modules/graphics.nix> # art & design
    ## Services
    <modules/services/docker.nix>
    <modules/services/keybase.nix>
    <modules/services/kubernetes.nix>
    <modules/services/mpd.nix>
    <modules/services/pia.nix>
    <modules/services/ssh.nix>
    <modules/services/syncthing.nix>
    <modules/services/transmission.nix>
    ## Theme
    <modules/themes/functional>
  ];

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";
  services.xserver.dpi = 186;

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
