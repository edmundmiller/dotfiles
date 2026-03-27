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
        # opnix: 1Password secrets injection for NixOS hosts
        inputs.opnix.nixosModules.default
      ]
      ++ optional (inputs ? openclaw-workspace) inputs.openclaw-workspace.nixosModules.openclaw
      ++ [
        # Add openclaw home-manager module for NixOS hosts
        # (overlay applied at flake level via mkPkgs)
        {
          home-manager.useGlobalPkgs = true;
          home-manager.sharedModules = [
            inputs.nix-openclaw.homeManagerModules.openclaw
            inputs.skills-catalog.homeManagerModules.default
          ];
        }
      ];
    };

  mapHosts = dir: attrs: mapModules dir (hostPath: mkHost hostPath attrs);
}
