{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./modules/editors/vim.nix

    ./modules/services/jellyfin.nix
    ./modules/services/ssh.nix
    ./modules/services/syncthing.nix

    ./modules/desktop/pantheon.nix

    ./modules/shell/zsh.nix
  ];

  networking.hostName = "rock";
  networking.networkmanager.enable = true;
  boot.loader.grub.enable = false;

  nixpkgs.config.allowUnsupportedSystem = true;

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
