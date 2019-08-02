{ config, lib, pkgs, ... }:

{
  imports = [ ./gnome.nix ./bspwm.nix ./autorandr.nix ];
  services.xserver = {
    displayManager.lightdm = {
      enable = true;
      # background = false;
    };
    desktopManager.xterm.enable = false;
  };
}
