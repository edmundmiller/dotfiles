{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/scan/not-detected.nix" ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "elevator=none"
    "mem_sleep_default=deep"
  ];

  ## The lone Windows install
  boot.loader.grub.useOSProber = true;

  ## CPU
  nix.settings.max-jobs = lib.mkDefault 16;
  powerManagement.cpuFreqGovernor = "performance";
  hardware.cpu.amd.updateMicrocode = true;

  ## HiDPI Monitors
  services.xserver.dpi = 140;
  fonts.fontconfig.hinting.enable = false;
  environment.variables = {
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.5";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
  };

  # TODO Check out https://github.com/Mic92/dotfiles/blob/master/nixos/modules/nfs-dl.nix
  # fileSystems."/data/media/music" = {
  #   device = "unas:/srv/nfs/music";
  #   fsType = "nfs";
  #   options = [
  #     "nofail"
  #     "noauto"
  #     "noatime"
  #     "x-systemd.automount"
  #     "x-systemd.idle-timeout=5min"
  #     "nodev"
  #     "nosuid"
  #     "noexec"
  #   ];
  # };

  # services.xserver = {
  #   ## Mice
  #   inputClassSections = [
  #     ''
  #       Identifier "My Mouse"
  #       MatchIsPointer "yes"
  #       Option "AccelerationProfile" "-1"
  #       Option "AccelerationScheme" "none"
  #       Option "AccelSpeed" "-1"
  #     ''
  #   ];

  #   ## Monitors
  #   monitorSection = ''
  #     VendorName     "Unknown"
  #     ModelName      "GBT Gigabyte M32U"
  #     HorizSync       255.0 - 255.0
  #     VertRefresh     48.0 - 144.0
  #     Option         "DPMS"
  #   '';
  #   screenSection = ''
  #     Option         "Stereo" "0"
  #     Option         "nvidiaXineramaInfoOrder" "DFP-3"
  #     Option         "metamodes" "DP-2: 3840x2160_144 +0+840, HDMI-0: nvidia-auto-select +3840+0 {rotation=right}"
  #     Option         "SLI" "Off"
  #     Option         "MultiGPU" "Off"
  #     Option         "BaseMosaic" "off"
  #   '';
  # };
}
