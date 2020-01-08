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

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-19.09";
  };

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
