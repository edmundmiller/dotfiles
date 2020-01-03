{ config, lib, pkgs, ... }:

{
  imports = [ ./. ];

  services = {
    printing.enable = true;
    pantheon.contractor.enable = true;

    xserver = {
      desktopManager.pantheon.enable = true;
      desktopManager.xterm.enable = false;

      displayManager.lightdm = {
        enable = true;
        greeters.gtk.enable = true;
      };
    };
  };
}
