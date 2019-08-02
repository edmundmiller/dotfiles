{ config, lib, pkgs, ... }:

{
  imports = [ ./xserver.nix ./gtk.nix ];
  services.xserver = {
    desktopManager.gnome3.enable = true;
    # services.gnome3.chrome-gnome-shell.enable = true;

    # displayManager = {
    #   gdm.enable = true;
    #   gdm.wayland = false;
    # };
  };
}
