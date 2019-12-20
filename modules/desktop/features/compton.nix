{ config, lib, pkgs, ... }:

{
  services.compton = {
    enable = true;
    vSync = true;
    shadow = true;
    shadowOpacity = "0.15";
    shadowOffsets = [ (-3) 0 ];
    shadowExclude = [
      "n:e:Notification"
      "class_i = 'Dunst'"
      "class_i = 'presel_feedback'"
      "g:e:Conky"
    ];
    refreshRate = 0;
    wintypes = {
      tooltip = {
        fade = true;
        shadow = false;
        opacity = 0.85;
        focus = true;
      };
    };
    settings = {
      no-dock-shadow = true;
      no-dnd-shadow = true;
      clear-shadow = true;
      shadow-radius = 4;
      shadow-ignore-shaped = true;

      inactive-dim = 0.15;
      inactive-opacity-override = false;
      opacity-rule = [ "80:class_g = 'Bspwm' && class_i = 'presel_feedback'" ];
      alpha-step = 6.0e-2;

      detect-rounded-corners = true;

      focus-exclude = [ "class_g = 'Vlc'" "class_g = 'mpv'" ];
    };
  };
}
