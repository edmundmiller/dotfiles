{ config, lib, pkgs, ... }:

{
  imports = [ ./features/xserver.nix ./features/gtk.nix ];

  environment.systemPackages = with pkgs; [
    gnomeExtensions.topicons-plus
    gnomeExtensions.mediaplayer
  ];

  services = {
    printing.enable = true;
    gnome3.chrome-gnome-shell.enable = true;
    dbus.packages = with pkgs; [ gnome3.dconf ];

    xserver = {
      desktopManager.gnome3.enable = true;

      displayManager = {
        gdm.enable = true;
        gdm.wayland = false;
      };
    };
  };
}
