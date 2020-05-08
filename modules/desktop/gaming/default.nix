{ config, lib, pkgs, ... }:

{
  imports = [
    ./factorio.nix
    # ./runelite.nix
    ./steam.nix
  ];
}
