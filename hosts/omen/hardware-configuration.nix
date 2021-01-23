# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "elevator=none" ];

  ## CPU
  nix.maxJobs = lib.mkDefault 12;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.intel.updateMicrocode = true;

  # Power management
  environment.systemPackages = [ pkgs.acpi ];
  services.tlp.enable = true;
  # Monitor backlight control
  programs.light.enable = true;
  user.extraGroups = [ "video" ];

  services.xserver.libinput.enable = true;
  services.xserver.libinput.disableWhileTyping = true;
  services.xserver.xkbOptions = "caps:escape";
  ## Ledger
  hardware.ledger.enable = true;

  ## picom lags in emacs and st
  services.picom.vSync = true;

  ## ZFS
  networking.hostId = "12a28d45";
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.grub.copyKernels = true;
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

  fileSystems."/home" = {
    device = "tank/user/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5216-74C6";
    fsType = "vfat";
  };

  fileSystems."/data/media/mail" = {
    device = "datatank/media/mail";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  fileSystems."/data/media/music" = {
    device = "datatank/media/music";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  fileSystems."/data/media/video" = {
    device = "datatank/media/video";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  fileSystems."/data/media/archive" = {
    device = "datatank/media/archive";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/bd5404de-c7bb-46c9-b78a-36a8e17d77ac"; }];

  services.xserver = {
    ## Monitors
    monitorSection = ''
      VendorName     "Unknown"
      ModelName      "CMN"
      HorizSync       45.3 - 67.9
      VertRefresh     40.0 - 60.0
      Option         "DPMS"
    '';
    screenSection = ''
      Option         "Stereo" "0"
      Option         "nvidiaXineramaInfoOrder" "DFP-1"
      Option         "metamodes" "nvidia-auto-select +0+0"
      Option         "SLI" "Off"
      Option         "MultiGPU" "Off"
      Option         "BaseMosaic" "off"
    '';
  };
}
