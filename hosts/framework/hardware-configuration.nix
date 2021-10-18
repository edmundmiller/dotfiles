# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "elevator=none" "mem_sleep_default=deep" ];

  ## CPU
  nix.maxJobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = true;

  # Power management
  environment.systemPackages = [ pkgs.acpi ];
  services.auto-cpufreq.enable = true;

  # Monitor backlight control
  programs.light.enable = true;
  user.extraGroups = [ "video" ];

  services.xserver.libinput.enable = true;
  services.xserver.libinput.touchpad.disableWhileTyping = true;
  services.xserver.xkbOptions = "caps:escape";

  # For fingerprint support
  services.fprintd.enable = true;

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
  services.xserver.dpi = 200;

  ## ZFS
  networking.hostId = "0dd71c1c";
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.grub.copyKernels = true;
  boot.zfs.enableUnstable = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  fileSystems."/" = {
    device = "tank/system/root";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "tank/system/var";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "tank/local/nix";
    fsType = "zfs";
  };

  fileSystems."/home/emiller" = {
    device = "tank/user/home/emiller";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D788-4E8A";
    fsType = "vfat";
  };

  swapDevices = [ ];
}
