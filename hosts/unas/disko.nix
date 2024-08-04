# FIXME https://github.com/KornelJahn/nixos-disko-zfs-test/blob/main/hosts/testhost-disko.nix
{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];
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
                mountOptions = [ "defaults" ];
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
      }; # nvme
      hdd1 = {
        # In slot 1
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_2PHTEHKT";
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
        # In slot 6
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_3HGZMWEN";
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
    }; # disk
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
            options.mountpoint = "legacy";
            mountpoint = "/";
          };
          "system/var" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/var";
            options = {
              xattr = "sa";
              acltype = "posixacl";
            };
          };
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };

          "user/home/emiller" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home/emiller";
            # TODO neededForBoot = true;
          };
          "user/home/monimiller" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home/monimiller";
            # TODO neededForBoot = true;
          };
          "user/home/tdmiller" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
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
            options.mountpoint = "legacy";
            mountpoint = "/data/media/books/audiobooks";
          };
          "media/books/ebooks" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/books/ebooks";
          };
          "docs" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/docs";
            options."com.sun:auto-snapshot" = "true";
          };
          "media/downloads" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/downloads";
          };
          "media/video/shows" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/video/shows";
          };
          "media/video/movies" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/video/movies";
          };
          "media/music" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/music";
          };
          "media/photos" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/data/media/photos";
          };
        };
      };
    }; # zpool
  };
}
