# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.nixos-hardware.nixosModules.framework-11th-gen-intel
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];
  boot.kernelParams = ["elevator=none" "mem_sleep_default=deep"];

  ## CPU
  nix.settings.max-jobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = true;

  # Power management
  environment.systemPackages = [pkgs.acpi];
  services.auto-cpufreq.enable = true;
  services.thermald.enable = true;

  # Monitor backlight control
  hardware.brillo.enable = true;
  user.extraGroups = ["video"];

  services.xserver.libinput.enable = true;
  services.xserver.libinput.touchpad.disableWhileTyping = true;
  services.xserver.xkb.options = "caps:escape";

  # Fingerprint gnome fix
  # https://github.com/NixOS/nixpkgs/issues/171136#issuecomment-1627779037
  security.pam.services.login.fprintAuth = false;
  # similarly to how other distributions handle the fingerprinting login
  security.pam.services.gdm-fingerprint = lib.mkIf config.services.fprintd.enable {
    text = ''
      auth       required                    pam_shells.so
      auth       requisite                   pam_nologin.so
      auth       requisite                   pam_faillock.so      preauth
      auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
      auth       optional                    pam_permit.so
      auth       required                    pam_env.so
      auth       [success=ok default=1]      ${pkgs.gnome.gdm}/lib/security/pam_gdm.so
      auth       optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so

      account    include                     login

      password   required                    pam_deny.so

      session    include                     login
      session    optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
    '';
  };

  # high-resolution display
  fonts.fontconfig.hinting.enable = false;

  # Fix font sizes in X
  services.xserver.dpi = 201;

  # Fix sizes of GTK/GNOME ui elements
  environment.variables = {
    GDK_SCALE = lib.mkDefault "2";
    GDK_DPI_SCALE = lib.mkDefault "0.5";
  };

  # Framework firmware
  services.fwupd.enable = true;

  # Dell WD19TB Dock
  services.hardware.bolt.enable = true;

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
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D788-4E8A";
    fsType = "vfat";
  };

  # FIXME Use user
  fileSystems."/home/emiller/.local/share/atuin" = {
    device = "/dev/zvol/tank/system/atuin ";
    fsType = "ext4";
  };

  swapDevices = [];
}
