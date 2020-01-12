{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./modules/editors/vim.nix

    ./modules/services/jellyfin.nix
    ./modules/services/ssh.nix
    ./modules/services/syncthing.nix

    ./modules/desktop/pantheon.nix

    ./modules/shell/zsh.nix
  ];

  networking.hostName = "rock";
  networking.networkmanager.enable = true;
  boot = {
    tmpOnTmpfs = true;
    loader.grub = {
      enable = false;
      version = 2;
      device = "nodev";
    };
    loader.generic-extlinux-compatible = { enable = true; };
    kernelPackages = pkgs.linuxPackagesFor (pkgs.buildLinux (pkgs // {
      /* src=/home/user/linux-test.tar.xz;
         version="5.4-rc8test";
         modDirVersion="5.4.0-rc8-MANJARO-ARM";
      */
      src = /home/user/linux-5.5-rc5.tar.xz;
      version = "5.5-rc5pbp";
      modDirVersion = "5.5.0-rc5-MANJARO-ARM";
      /* src=/home/user/linux-5.4.6.tar.gz;
         version="5.4.6pbp";
         modDirVersion="5.4.6-MANJARO-ARM";
      */
      autoModules = false;
      defconfig = "pinebook_pro_defconfig";
      kernelPatches = [
        {
          extraConfig = "CRYPTO_AEGIS128_SIMD n";
          patch = null;
          name = "no_aegis128_simd";
        }
        {
          patch = null;
          name = "reduced";
          extraConfig = ''
            ARM64_SVE n
            PCI_XGENE n
            PCI_HISI n
            AHCI_XGENE n
            DRM_RADEON n
            DRM_AMDGPU n
            DRM_NOUVEAU n
            MFD_CROS_EC n
            COMMON_CLK_XGENE n
            PHY_QCOM_USB_HS n
            PHY_QCOM_USB_HSIC n
            HISI_PMU n
            LIBNVDIMM n
            BLK_DEV_PMEM n
            ND_BLK n
            MEDIA_SUPPORT n
            STAGING n
            MISC_FILESYSTEMS n
            NETWORK_FILESYSTEMS n
          '';
        }
        {
          patch = null;
          name = "psci-cpuidle";
          extraConfig = "ARM_PSCI_CPUIDLE n";
        }
      ];
    }));
    supportedFilesystems = lib.mkForce [ ];
    initrd.supportedFilesystems = lib.mkForce [ ];
  };

  users.users.emiller.extraGroups = [ "networkmanager" ];
}
