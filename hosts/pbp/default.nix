{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix
    ## Desktop/shell environment
    <modules/desktop/sway.nix>
    ## Apps
    #<modules/browser/firefox.nix>
    #<modules/dev/nix.nix>
    <modules/dev/node.nix>
    #<modules/dev/python.nix>
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

  environment.systemPackages = with pkgs; [
    acpi
    uBootPinebookProExternalFirst
    firefox
  ];

  #
  # Monitor backlight control
  programs.light.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowBroken = true;
  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
}
