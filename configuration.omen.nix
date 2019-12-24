{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./modules/base.nix
    ./modules/desktop/default.nix
    ./modules/dev/default.nix
    ./modules/editors/vscode.nix

    ./modules/audio/ncmpcpp+mpd.nix

    ./modules/services/keybase.nix
    ./modules/services/pia.nix
    ./modules/services/ssh.nix
    ./modules/services/syncthing.nix

    ./modules/gaming/steam.nix

    # ./modules/desktop/gnome.nix
    ./modules/desktop/bspwm.nix
    ./modules/desktop/features/autorandr/omen.nix

    ./modules/shell/pass.nix
    ./modules/shell/mail.nix
  ];

  boot.loader.grub = {
    useOSProber = true;
    configurationLimit = 30;
  };

  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-19.09";
  };

  environment.systemPackages = [ pkgs.powertop pkgs.lm_sensors ];
  services.tlp.enable = true;
  powerManagement.powertop.enable = true;

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 15d";
  };

  # Monitor backlight control
  programs.light.enable = true;

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
