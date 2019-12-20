{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    # Hardware
    ./hardware/storage.nix

    ./modules/base.nix
    ./modules/desktop/default.nix
    ./modules/dev/default.nix
    ./modules/editors/vscode.nix

    ./modules/audio/ncmpcpp+mpd.nix

    ./modules/services/default.nix
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

  fonts = {
    fontconfig = {
      enable = true;
      antialias = true;
      defaultFonts.monospace = [ "Iosevka" ];
      allowBitmaps = true;
      useEmbeddedBitmaps = true;
      ultimate = {
        enable = true;
        substitutions = "combi";
      };
    };
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
      package = pkgs.pulseaudioFull;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
