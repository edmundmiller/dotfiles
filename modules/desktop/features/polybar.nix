{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (polybar.override {
      mpdSupport = true;
      pulseSupport = true;
      nlSupport = true;
    })
    killall
  ];

  fonts.fonts = [ pkgs.siji ];

  home-manager.users.emiller.xdg.configFile = {
    "polybar" = {
      source = <config/polybar>;
      recursive = true;
    };
  };
}