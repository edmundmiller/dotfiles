{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SHGP31-1000GM-2_AJ0BN90921070C30T";
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
      }; # nvme0
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
          # zfs create -o refreservation=10G -o mountpoint=none zroot/reserved
          # https://wiki.nixos.org/wiki/ZFS#Reservations
          "reserved" = {
            type = "zfs_fs";
            mountpoint = null;
            options.refreservation = "200G";
          };
        };
      };
    }; # zpool
  };
}
