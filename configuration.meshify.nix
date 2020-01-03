{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./modules/base.nix
    ./modules/dev/default.nix
    ./modules/editors/vim.nix

    ./modules/audio/ncmpcpp+mpd.nix

    ./modules/services/keybase.nix
    ./modules/services/pia.nix
    ./modules/services/ssh.nix
    ./modules/services/syncthing.nix
    ./modules/services/transmission.nix

    ./modules/gaming/steam.nix
    ./modules/gaming/runelite.nix

    ./modules/desktop/bspwm.nix
    ./modules/desktop/features/autorandr/meshify.nix

    ./modules/shell/pass.nix
    ./modules/shell/mail.nix
  ];

  networking.hostName = "meshify";
  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  services.xserver.videoDrivers = [ "nvidiaBeta" ];

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-19.09";
  };

  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.grub.copyKernels = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "rpool/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = { dataset = "bigdata/backup"; };
      };
    };
  };

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 15d";
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
