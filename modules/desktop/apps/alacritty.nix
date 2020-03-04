{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ unstable.alacritty ];

    home.xdg.configFile."alacritty" = {
      source = <config/alacritty>;
      recursive = true;
    };
  };
}
