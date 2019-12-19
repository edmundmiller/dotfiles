{ config, lib, pkgs, ... }:

{
  imports = [ ./features/xserver.nix ./features/gtk.nix ];

  environment.systemPackages = with pkgs; [
    gnomeExtensions.topicons-plus
    gnomeExtensions.mediaplayer
  ];
  services.xserver = {
    desktopManager.gnome3.enable = true;

    displayManager = {
      gdm.enable = true;
      gdm.wayland = false;
    };
  };
}
