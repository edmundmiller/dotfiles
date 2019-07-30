{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ polybar ];

  home-manager.users.emiller.xdg.configFile = {
    "polybar" = {
      source = <config/polybar>;
      recursive = true;
    };
  };
}
