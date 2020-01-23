{ config, lib, pkgs, ... }:

{
  imports = [
    ../personal.nix
    ./hardware-configuration.nix

    <modules/editors/vim.nix>
    <modules/shell/zsh.nix>

    <modules/services/gitea.nix>
    <modules/services/grocy.nix>
    <modules/services/jellyfin.nix>
    <modules/services/nginx.nix>
    <modules/services/ssh.nix>
    <modules/services/syncthing.nix>

  ];

  networking.hostName = "rock";
  networking.networkmanager.enable = true;
  networking.localCommands = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx off tx off
  '';

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
