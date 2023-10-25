{inputs, ...}: {
  # inputs is made accessible by passing it as a specialArg to nixosSystem{}
  imports = [
    inputs.disko.nixosModules.disko
  ];
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/disk/by-id/ata-SATA_SSD_21111524000111";
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
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        postCreateHook = "zfs snapshot zroot@blank";
        datasets = {
          "system" = {
            type = "zfs_fs";
            mountpoint = "none";
          };
          "system/root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "system/var" = {
            type = "zfs_fs";
            mountpoint = "/var";
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
