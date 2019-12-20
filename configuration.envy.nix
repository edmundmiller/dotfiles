{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./modules/base.nix
    ./modules/default/desktop.nix
    ./modules/dev/default.nix
    ./modules/editors/vscode.nix

    ./modules/services/default.nix

    ./modules/desktop/gnome.nix
    # ./modules/desktop/bspwm.nix

    ./modules/shell/pass.nix
  ];

  boot.loader.grub = { configurationLimit = 30; };

  networking.hostName = "envy";
  # networking.wireless.enable = true;
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

  users.users.lori = {
    isNormalUser = true;
    uid = 1001;
    description = "Lori Miller";
    extraGroups = [ "video" ];
  };
}
