{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S59ANM0W302035F";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
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
        };
      };
    };
  };
}
