{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix
    # FIXME Download the repo automatically
    ./wip-pinebook-pro/pinebook_pro.nix
    ## Desktop/shell environment
    <modules/desktop/bspwm.nix>
    ## Apps
    <modules/browser/firefox.nix>
    <modules/dev/nix.nix>
    <modules/dev/node.nix>
    <modules/dev/python.nix>
    <modules/editors/emacs.nix>
    <modules/editors/vim.nix>
    <modules/shell/direnv.nix>
    <modules/shell/git.nix>
    <modules/shell/gnupg.nix>
    <modules/shell/pass.nix>
    <modules/shell/tmux.nix>
    <modules/shell/yubikey.nix>
    <modules/shell/zsh.nix>
    ## Project-based
    # <modules/music.nix> # playing music
    # <modules/graphics.nix> # art & design
    ## Services
    <modules/services/docker.nix>
    <modules/services/keybase.nix>
    # FIXME <modules/services/pia.nix>
    <modules/services/syncthing.nix>
    ## Theme
    <modules/themes/functional>
  ];

  networking.hostName = "pbp";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  environment.systemPackages = [ pkgs.acpi pkgs.uBootPinebookProExternalFirst ];
  #
  # Monitor backlight control
  programs.light.enable = true;
}
