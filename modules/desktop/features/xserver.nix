{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    layout = "us";
    xkbOptions = "caps:escape";
    videoDrivers = [ "nvidiaBeta" ];
    libinput = {
      enable = true;
      disableWhileTyping = true;
      tapping = false;
    };

    desktopManager.xterm.enable = false;
  };
}
