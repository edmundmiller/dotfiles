{ config, lib, pkgs, ... }:

{
  imports = [
    ./bspwm.nix
    ./gnome.nix
    ./stumpwm.nix

    ./apps
    ./term
    ./browsers
    ./gaming
  ];
}
