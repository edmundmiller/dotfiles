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
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  environment.variables = {
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.5";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2 -Dawt.useSystemAAFontSettings=lcd";
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

  ## Harddrives
  fileSystems."/data/media/movies" = {
    device = "bigdata/media/movies";
    fsType = "zfs";
  };

  fileSystems."/data/media/music" = {
    device = "unas:/srv/nfs/music";
    fsType = "nfs";
      options = [
        "nofail" "noauto" "noatime" "x-systemd.automount" "x-systemd.idle-timeout=5min"
        "nodev" "nosuid" "noexec"
      ];
  };

  fileSystems."/data/media/shows" = {
    device = "bigdata/media/shows";
    fsType = "zfs";
  };

  fileSystems."/data/media/torrents" = {
    device = "bigdata/media/torrents";
    fsType = "zfs";
  };

  fileSystems."/data/archive" = {
    device = "bigdata/archive";
    fsType = "zfs";
  };

  fileSystems."/data/mail" = {
    device = "bigdata/mail";
    fsType = "zfs";
  };

  fileSystems."/data/genomics" = {
    device = "bigdata/genomics";
    fsType = "zfs";
  };

  fileSystems."/data/media/books" = {
    device = "bigdata/media/books";
    fsType = "zfs";
  };

  swapDevices = [ ];

  services.xserver = {
    ## Mice
    inputClassSections = [''
      Identifier "My Mouse"
      MatchIsPointer "yes"
      Option "AccelerationProfile" "-1"
      Option "AccelerationScheme" "none"
      Option "AccelSpeed" "-1"
    ''];

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
      Option         "metamodes" "DP-2: nvidia-auto-select +3840+0, DP-0: nvidia-auto-select +0+0"
      Option         "SLI" "Off"
      Option         "MultiGPU" "Off"
      Option         "BaseMosaic" "off"
    '';
  };
}
