{
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  sys = "x86_64-linux";
in
{
  mkHost =
    path:
    attrs@{
      system ? sys,
      ...
    }:
    nixosSystem {
      inherit system;
      specialArgs = {
        inherit lib inputs system;
        isDarwin = false;
      };
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = mkDefault (removeSuffix ".nix" (baseNameOf path));
        }
        (filterAttrs (n: _v: !elem n [ "system" ]) attrs)
        ../.
        (import path)
        # Add openclaw home-manager module for NixOS hosts
        # (overlay applied at flake level via mkPkgs)
        {
          home-manager.useGlobalPkgs = true;
          home-manager.sharedModules = [
            inputs.nix-openclaw.homeManagerModules.openclaw
          ];
        }
      ];
    };

  mapHosts = dir: attrs: mapModules dir (hostPath: mkHost hostPath attrs);
}
