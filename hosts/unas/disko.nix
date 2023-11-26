{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-PCIe_SSD_20092410240085";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "64M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        rootFsOptions = {
          compression = "on";
          "com.sun:auto-snapshot" = "false";
          mountpoint = "none";
          canmount = "off";
        };
        postCreateHook = "zfs snapshot zroot@blank";
        datasets = {
          "system" = {
            type = "zfs_fs";
            mountpoint = null;
          };
          "system/root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "system/var" = {
            type = "zfs_fs";
            mountpoint = "/var";
            options = {
              xattr = "sa";
              acltype = "posixacl";
            };
          };
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };

          "user/home/emiller" = {
            type = "zfs_fs";
            mountpoint = "/home/emiller";
            # TODO neededForBoot = true;
          };
          "user/home/monimiller" = {
            type = "zfs_fs";
            mountpoint = "/home/monimiller";
            # TODO neededForBoot = true;
          };
          "user/home/tdmiller" = {
            type = "zfs_fs";
            mountpoint = "/home/tdmiller";
            # TODO neededForBoot = true;
          };
        };
      };
    };
  };
}
