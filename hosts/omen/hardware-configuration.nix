# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [
    "dm-snapshot"
    # Required to open the EFI partition and Yubikey
    "vfat"
    "nls_cp437"
    "nls_iso8859-1"
    "usbhid"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  # The lone Windows install
  boot.loader.grub = {
    useOSProber = true;
    configurationLimit = 30;
  };

  ## CPU
  nix.maxJobs = lib.mkDefault 12;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  ## GPU
  services.xserver.videoDrivers = [ "nvidiaBeta" ];
  hardware.opengl.enable = true;
  # Respect XDG conventions, damn it!
  environment.systemPackages = with pkgs;
    [
      (writeScriptBin "nvidia-settings" ''
        #!${stdenv.shell}
        exec ${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-settings --config="$XDG_CONFIG_HOME/nvidia/settings"
      '')
    ];

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };
  services.blueman.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [ "noatime" ];

  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6937-90BD";
    fsType = "vfat";
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [{ device = "/dev/disk/by-label/swap"; }];

  ## yubikey luks
  boot.initrd.luks = {
    reusePassphrases = true;
    devices = {
      root = {
        device = "/dev/nvme0n1p5";
        preLVM = true;
        allowDiscards = true;
      };
      data = {
        device = "/dev/sda1";
        preLVM = true;
        allowDiscards = true;
      };
    };
  };

  services.xserver.xrandrHeads = [{
    output = "DP-0";
    primary = true;
    monitorConfig = ''
      DisplaySize 1920 1080
      Option "dpi" "110"
    '';
  }];
}
