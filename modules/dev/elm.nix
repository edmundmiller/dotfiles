{ config, lib, pkgs, ... }:

{
  my.packages = with pkgs; [
    elm2nix
    elmPackages.elm
    elmPackages.elm-format
    unstable.elmPackages.elm-language-server
  ];
}
