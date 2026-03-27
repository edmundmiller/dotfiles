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
    let
      hostName = removeSuffix ".nix" (baseNameOf path);
      openclawEnabledHosts = [ "nuc" ];
      enableOpenClaw = elem hostName openclawEnabledHosts;
    in
    nixosSystem {
      inherit system;
      specialArgs = {
        inherit lib inputs system;
        isDarwin = false;
      };
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = mkDefault hostName;
        }
        (filterAttrs (n: _v: !elem n [ "system" ]) attrs)
        ../.
        (import path)
        # opnix: 1Password secrets injection for NixOS hosts
        inputs.opnix.nixosModules.default
      ]
      ++ optional (
        enableOpenClaw && (inputs ? openclaw-workspace)
      ) inputs.openclaw-workspace.nixosModules.openclaw
      ++ [
        {
          home-manager.useGlobalPkgs = true;
          home-manager.sharedModules =
            optional enableOpenClaw inputs.nix-openclaw.homeManagerModules.openclaw
            ++ [ inputs.skills-catalog.homeManagerModules.default ];
        }
      ];
    };

  mapHosts = dir: attrs: mapModules dir (hostPath: mkHost hostPath attrs);
}
