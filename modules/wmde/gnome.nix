{ config, lib, pkgs, ... }:

{
  imports =
  [ ./features/xserver.nix ./features/gtk.nix ./features/lightdm.nix ];

  environment.systemPackages = with pkgs; [
    gnomeExtensions.topicons-plus
    gnomeExtensions.mediaplayer
  ];
  services.xserver = {
    desktopManager.gnome3.enable = true;
    services.gnome3.chrome-gnome-shell.enable = true;

    # displayManager = {
    #   gdm.enable = true;
    #   gdm.wayland = false;
    # };
  };
}
