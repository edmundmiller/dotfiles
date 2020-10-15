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
        Option "dpi" "163"
      '';
    }
    {
      output = "DP-4";
      monitorConfig = ''
        DisplaySize 3840 2160
        Option "dpi" "163"
        Option "RightOf" "DP-2"
      '';
      # NOTE Option "Rotate" "right"
    }
  ];
}
