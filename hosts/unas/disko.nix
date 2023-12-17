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
      hdd4 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD120EDAZ-11F3RA0_5PK8T7RF";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "datatank";
              };
            };
          };
        };
      };
      hdd5 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD180EDGZ-11B2DA0_3FH06MJT";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "datatank";
              };
            };
          };
        };
      };
      hdd6 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD120EDAZ-11F3RA0_5PK7HZAF";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "datatank";
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

      datatank = {
        type = "zpool";
        mode = "mirror";
        rootFsOptions = {
          compression = "on";
          "com.sun:auto-snapshot" = "false";
          mountpoint = "none";
          canmount = "off";
        };
        postCreateHook = "zfs snapshot datatank@blank";
        datasets = {
          "media/books/audiobooks" = {
            type = "zfs_fs";
            mountpoint = "/data/media/books/audiobooks";
            options.sharenfs = "on";
          };
          "media/books/ebooks" = {
            type = "zfs_fs";
            mountpoint = "/data/media/books/ebooks";
            options.sharenfs = "on";
          };
          "docs" = {
            type = "zfs_fs";
            mountpoint = "/data/docs";
            options."com.sun:auto-snapshot" = "true";
            options.sharenfs = "on";
          };
          "media/downloads" = {
            type = "zfs_fs";
            mountpoint = "/data/media/downloads";
            options.sharenfs = "on";
          };
          "media/video/shows" = {
            type = "zfs_fs";
            mountpoint = "/data/media/video/shows";
            options.sharenfs = "on";
          };
          "media/video/movies" = {
            type = "zfs_fs";
            mountpoint = "/data/media/video/movies";
            options.sharenfs = "on";
          };
          "media/music" = {
            type = "zfs_fs";
            mountpoint = "/data/media/music";
            options.sharenfs = "on";
          };
          "media/photos" = {
            type = "zfs_fs";
            mountpoint = "/data/media/photos";
            options.sharenfs = "on";
          };
        };
      };
    };
  };
}
