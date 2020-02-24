{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ alacritty ];

    home.xdg.configFile."alacritty" = {
      source = <config/alacritty>;
      recursive = true;
    };
  };
}
