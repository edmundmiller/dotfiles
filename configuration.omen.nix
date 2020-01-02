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
    ./modules/shell/yubikey.nix
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

  boot.initrd = {
    # Required to open the EFI partition and Yubikey
    kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" "usbhid" ];

    luks = {
      #   # Update if necessary
      #   cryptoModules = [ "aes" "xts" "sha512" ];

      # Support for Yubikey PBA
      yubikeySupport = true;
      reusePassphrases = true;

      devices = [
        {
          name = "root";
          device = "/dev/nvme0n1p5";
          preLVM = true;
          allowDiscards = true;

          yubikey = {
            slot = 2;
            twoFactor = true; # Set to false for 1FA
            gracePeriod =
              30; # Time in seconds to wait for Yubikey to be inserted
            keyLength = 64; # Set to $KEY_LENGTH/8
            saltLength = 16; # Set to $SALT_LENGTH

            storage = {
              device =
                "/dev/nvme0n1p1"; # Be sure to update this to the correct volume
              fsType = "vfat";
              path = "/crypt-storage/default";
            };
          };
        }
        {
          name = "encrypted";
          device = "/dev/sda1"; # Be sure to update this to the correct volume

          yubikey = {
            slot = 2;
            twoFactor = true; # Set to false for 1FA
            gracePeriod =
              30; # Time in seconds to wait for Yubikey to be inserted
            keyLength = 64; # Set to $KEY_LENGTH/8
            saltLength = 16; # Set to $SALT_LENGTH

            storage = {
              device =
                "/dev/nvme0n1p1"; # Be sure to update this to the correct volume
              fsType = "vfat";
              path = "/crypt-storage/data";
            };
          };
        }
      ];
    };
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
