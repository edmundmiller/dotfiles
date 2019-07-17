{ config, lib, pkgs, options, ... }:

let
  nixosConfig = builtins.toFile "configuration.nix" ''
# https://github.com/bennofs/etc-nixos/blob/master/default.nix
in
{
  nix.nixPath = options.nix.nixPath.default ++ [ "config=${./config}" ];
}
