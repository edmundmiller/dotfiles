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

  ## Mouse
  services.xserver.libinput.accelProfile = "flat";

  ## Monitors
  environment.variables.GDK_SCALE = "2";
  environment.variables.GDK_DPI_SCALE = "0.5";

  ## SSD
  fileSystems."/" = {
    device = "tank/system/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "tank/local/nix";
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
    device = "bigdata/media/music";
    fsType = "zfs";
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

  ## Monitors
  services.xserver.xrandrHeads = [
    {
      output = "DP-2";
      primary = true;
      monitorConfig = ''
        DisplaySize 3840 2160
      '';
    }
    {
      output = "DP-0";
      monitorConfig = ''
        DisplaySize 3840 2160
        Option "RightOf" "DP-2"
      '';
      # NOTE Option "Rotate" "right"
    }
    #{
    #  output = "DP-4";
    #  monitorConfig = ''
    #    DisplaySize 1920 1080
    #    Option "LeftOf" "DP-2"
    #    Option "Rotate" "right"
    #    ModeLine "1920x1080     60.00 + 239.76*  144.00   119.93    99.90    84.88    59.94    50.00"
    #    Option "PreferredMode" "1920x1080"
    #  '';
    #}
  ];
}
