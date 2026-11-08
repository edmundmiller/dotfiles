{
  config,
  inputs,
  lib,
  ...
}:
let
  systemUuid = "89097bd0-010c-4b38-b618-eeac591a617c";
  bulkUuid = "28175add-006e-4f18-93aa-e9bea3400d02";
  mountOptions = [
    "compress=zstd:1"
    "noatime"
  ];
  bulkMountOptions = mountOptions ++ [
    "nofail"
    "x-systemd.device-timeout=10s"
  ];
  # Set the top-level inode mode before optional mounts can expose it at boot.
  rootOnlyTopLevelHook = ''
    (
      MNTPOINT=$(mktemp -d)
      mount "$device" "$MNTPOINT" -o subvolid=5
      trap 'umount "$MNTPOINT"; rmdir "$MNTPOINT"' EXIT
      chmod 0700 "$MNTPOINT"
    )
  '';
  systemSubvolumes =
    lib.mapAttrs
      (_: mountpoint: {
        inherit mountpoint mountOptions;
      })
      {
        "@root" = "/";
        "@home" = "/home";
        "@var" = "/var";
        "@nix" = "/nix";
        "@snapshots" = "/.snapshots";
        "@legacy-zfs" = "/var/lib/unas-zfs-history";
      };
  bulkSubvolumes =
    lib.mapAttrs
      (_: mountpoint: {
        inherit mountpoint;
        mountOptions = bulkMountOptions;
      })
      {
        "@data" = "/data";
        "@backup" = "/data/backup";
        "@docs" = "/data/docs";
        "@audiobooks" = "/data/media/books/audiobooks";
        "@ebooks" = "/data/media/books/ebooks";
        "@downloads" = "/data/media/downloads";
        "@shows" = "/data/media/video/shows";
        "@movies" = "/data/media/video/movies";
        "@music" = "/data/media/music";
        "@photos" = "/data/media/photos";
        "@legacy-zfs-copy" = "/data/legacy-zfs";
        "@snapshots" = "/data/.snapshots";
      };
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk = {
    # Disk names determine creation order. Prepare this empty member before hdd6.
    hdd1 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_2PHTEHKT";
      content = {
        type = "gpt";
        partitions.bulk.size = "100%";
      };
    };
    hdd6 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_3HGZMWEN";
      content = {
        type = "gpt";
        partitions.bulk = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "unas-bulk"
              "-U"
              bulkUuid
              "-d"
              "raid1"
              "-m"
              "raid1"
              config.disko.devices.disk.hdd1.content.partitions.bulk.device
            ];
            postCreateHook = rootOnlyTopLevelHook;
            subvolumes = bulkSubvolumes;
          };
        };
      };
    };
    nvme = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-PCIe_SSD_20092410240085";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          system = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "unas-system"
                "-U"
                systemUuid
                "-d"
                "single"
                "-m"
                "dup"
              ];
              postCreateHook = rootOnlyTopLevelHook;
              subvolumes = systemSubvolumes;
            };
          };
        };
      };
    };
  };

  fileSystems =
    lib.mapAttrs' (
      _: subvolume:
      lib.nameValuePair subvolume.mountpoint {
        device = lib.mkForce "/dev/disk/by-uuid/${systemUuid}";
      }
    ) systemSubvolumes
    // lib.mapAttrs' (
      _: subvolume:
      lib.nameValuePair subvolume.mountpoint {
        device = lib.mkForce "/dev/disk/by-uuid/${bulkUuid}";
        neededForBoot = false;
      }
    ) bulkSubvolumes
    // {
      "/.btrfs" = {
        device = "/dev/disk/by-uuid/${systemUuid}";
        fsType = "btrfs";
        options = mountOptions ++ [ "subvolid=5" ];
      };
      "/.btrfs-bulk" = {
        device = "/dev/disk/by-uuid/${bulkUuid}";
        fsType = "btrfs";
        options = bulkMountOptions ++ [ "subvolid=5" ];
        neededForBoot = false;
      };
    };

  # These permissions apply to the filesystem top levels, not the share subvolumes.
  systemd.tmpfiles.rules = [
    "d /.btrfs 0700 root root -"
    "d /.btrfs-bulk 0700 root root -"
  ];
}
