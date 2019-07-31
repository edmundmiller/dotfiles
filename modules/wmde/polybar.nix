{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (polybar.override { pulseSupport = true; })
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
