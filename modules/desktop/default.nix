{ config, lib, pkgs, ... }:

{
  imports = [
    ./bspwm.nix
    # TODO ./stumpwm.nix

    ./apps
    ./term
    ./browsers
    ./gaming
  ];
}
