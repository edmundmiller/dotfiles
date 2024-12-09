{ lib, pkgs, ... }:
{
    imports = [
        # ../home.nix
        # ./disko.nix
        # ./hardware-configuration.nix
    ];
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 5;

}
