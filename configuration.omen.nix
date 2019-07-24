{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    # Hardware
    ./hardware/storage.nix

    ./services/default.nix
    ./modules/dev.nix
    ./modules/steamcontroller.nix
  ];

  networking.hostName = "nixos-omen";
  # networking.wireless.enable = true;

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-unstable";
  };

  environment.systemPackages = [ pkgs.powertop ];
  services.tlp.enable = true;
  powerManagement.powertop.enable = true;
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Monitor backlight control
  programs.light.enable = true;

  fonts = {
    fontconfig.defaultFonts.monospace = [ "Iosevka" ];
    fonts = with pkgs; [
      fira-code-symbols
      iosevka
      noto-fonts
      symbola
      noto-fonts-cjk
      font-awesome_5
    ];
  };

  # Enable sound.
  sound.enable = true;
  hardware = {
    opengl.driSupport32Bit = true;
    pulseaudio = {
      enable = true;
      support32Bit = true;
    };
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
