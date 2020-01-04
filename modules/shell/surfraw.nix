{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ surfraw ];

  home-manager.users.emiller.xdg.configFile = {
    "surfraw".source = <config/surfraw>;
  };
}
