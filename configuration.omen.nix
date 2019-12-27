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

  services.xserver.videoDrivers = [ "nvidiaBeta" ];

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

  # Minimal list of modules to use the EFI system partition and the YubiKey
  boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" "usbhid" ];

  # Crypto setup, set modules accordingly
  boot.initrd.luks.cryptoModules = [ "aes" "xts" "sha512" ];

  # Enable support for the YubiKey PBA
  boot.initrd.luks.yubikeySupport = true;

  # Configuration to use your Luks device
  boot.initrd.luks.devices = [{
    name = "nixos-enc";
    device = "/dev/nvme0np5";
    preLVM = true;
    yubikey = {
      slot = 2;
      twoFactor = true; # Set to false if you did not set up a user password.
      storage = { device = "/dev/nvmeon1p1"; };
    };
  }];
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
