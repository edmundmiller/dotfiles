{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix

    ## Desktop/shell environment
    <modules/desktop/bspwm.nix>
    ./modules/audio/ncmpcpp+mpd.nix

    <modules/browser/firefox.nix>
    <modules/base.nix> # FIXME
    <modules/dev/default.nix> # TODO consider individual imports
    <modules/editors/emacs.nix>
    <modules/editors/vim.nix>
    <modules/gaming/steam.nix>

    <modules/audio/ncmpcpp+mpd.nix>
    <modules/shell/pass.nix>
    <modules/shell/mail.nix>
    <modules/shell/yubikey.nix>

    <modules/desktop/autorandr/omen.nix>

    <themes/functional>
  ];

  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  time.timeZone = "America/chicago";

  environment.systemPackages = [ pkgs.acpi ];
  powerManagement.powertop.enable = true;
  # Monitor backlight control
  programs.light.enable = true;
}
