{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    layout = "us";
    xkbOptions = "caps:escape";
    libinput = {
      enable = true;
      disableWhileTyping = true;
      tapping = false;
    };

    desktopManager.xterm.enable = false;
  };
}
