{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ libinput libinput-gestures wmctrl ];

    user.extraGroups = [ "input" ];

    home.xdg.configFile = {
      "libinput-gestures.conf" = { source = <config/libinput-gestures.conf>; };
    };
  };
}
