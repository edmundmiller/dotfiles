{ config, lib, pkgs, ... }:

{
  imports = [ ./. ./features/xserver.nix ./features/gtk.nix ];

  services = {
    printing.enable = true;
    pantheon.contractor.enable = true;

    xserver = {
      desktopManager.pantheon.enable = true;

      displayManager.lightdm = {
        enable = true;
        greeters.gtk.enable = true;
      };
    };
  };
}
