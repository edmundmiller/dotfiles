{ config, lib, pkgs, ... }:

{
  services = {
    gnome3.chrome-gnome-shell.enable = true;

    xserver = {
      enable = true;
      layout = "us";
      xkbOptions = "caps:escape";
      videoDrivers = [ "nvidiaBeta" ];
      libinput = {
        enable = true;
        disableWhileTyping = true;
        tapping = false;
      };

      displayManager = {
        gdm.enable = true;
        gdm.wayland = false;
      };
      desktopManager = {
        gnome3 = { enable = true; };
      };
    };
  };
}
