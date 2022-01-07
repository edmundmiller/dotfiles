{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ "${modulesPath}/installer/scan/not-detected.nix" ];

  boot.initrd.availableKernelModules =
    [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "elevator=none" ];

  ## The lone Windows install
  boot.loader.grub.useOSProber = true;

  ## CPU
  nix.maxJobs = lib.mkDefault 16;
  powerManagement.cpuFreqGovernor = "performance";
  hardware.cpu.amd.updateMicrocode = true;

  ## HiDPI Monitors
  hardware.video.hidpi.enable = lib.mkDefault true;
  services.xserver.dpi = 192;
  fonts.fontconfig.hinting.enable = false;
  environment.variables = {
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.5";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
  };

  ## SSD
  fileSystems."/" = {
    device = "tank/system/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "tank/local/nix";
    fsType = "zfs";
  };

  fileSystems."/gnu" = {
    device = "tank/local/guix";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "tank/system/var";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "tank/user/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/C2C7-D952";
    fsType = "vfat";
  };

  # TODO Check out https://github.com/Mic92/dotfiles/blob/master/nixos/modules/nfs-dl.nix
  fileSystems."/data/media/music" = {
    device = "unas:/srv/nfs/music";
    fsType = "nfs";
    options = [
      "nofail"
      "noauto"
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
      "nodev"
      "nosuid"
      "noexec"
    ];
  };

  swapDevices = [ ];

  services.xserver = {
    ## Mice
    inputClassSections = [
      ''
        Identifier "My Mouse"
        MatchIsPointer "yes"
        Option "AccelerationProfile" "-1"
        Option "AccelerationScheme" "none"
        Option "AccelSpeed" "-1"
      ''
    ];

    ## Monitors
    monitorSection = ''
      VendorName     "Unknown"
      ModelName      "LG Electronics LG Ultra HD"
      HorizSync       30.0 - 135.0
      VertRefresh     56.0 - 61.0
      Option         "DPMS"
    '';
    screenSection = ''
      Option         "Stereo" "0"
      Option         "nvidiaXineramaInfoOrder" "DFP-3"
      Option         "metamodes" "DP-2: nvidia-auto-select +0+840, HDMI-0: nvidia-auto-select +3840+0 {rotation=right}"
      Option         "SLI" "Off"
      Option         "MultiGPU" "Off"
      Option         "BaseMosaic" "off"
    '';
  };
}
