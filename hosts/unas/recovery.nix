# Standalone live image. Never import default.nix or disko.nix here.
{
  lib,
  pkgs,
  recoveryKeys,
  ...
}:
{
  assertions = [
    {
      assertion = recoveryKeys != [ ];
      message = "UNAS recovery requires at least one SSH public key.";
    }
  ];

  networking.hostName = "unas-rescue";
  boot.loader.timeout = lib.mkForce 5;
  boot.supportedFilesystems = [ "zfs" ];
  # Upstream's optional latest-kernel entry disables ZFS. Keep the LTS entry.
  specialisation = lib.mkForce { };
  # Discovery is safe; pool imports and disk writes require inspection first.
  boot.zfs.forceImportRoot = false;
  boot.zfs.forceImportAll = false;
  boot.zfs.extraPools = [ ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = recoveryKeys;

  services.avahi = {
    enable = true;
    openFirewall = true;
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
    };
  };
  # openresolv sends SIGHUP before Avahi's startup signal handler is ready.
  # Let initial DNS configuration finish before advertising the rescue host.
  systemd.services.avahi-daemon = {
    after = [
      "network-online.target"
      "resolvconf.service"
    ];
    wants = [ "network-online.target" ];
  };

  environment.systemPackages = with pkgs; [
    git
    python3
    rsync
    smartmontools
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  isoImage.volumeID = "UNAS_RESCUE";
  isoImage.appendToMenuLabel = " - UNAS recovery (no automatic disk writes)";
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  services.getty.helpLine = lib.mkForce ''
    UNAS recovery is ready. Connect Ethernet and use:
      ssh root@unas-rescue.local

    SSH accepts only approved public keys. Console login needs no password.
    No NAS pool is imported and no disk is formatted automatically.
    Read /etc/unas-recovery.txt before reinstalling.
  '';

  environment.etc."unas-recovery.txt".text = ''
    UNAS data-preserving reinstall

    This USB boots a live system with Ethernet DHCP, SSH, Btrfs, and ZFS tools.
    It does not reinstall, partition, format, mount data filesystems, or import
    pools automatically. Disk writes require separate authorization.

    First inspect lsblk -f, findmnt, and /dev/disk/by-id. Confirm filesystem
    types, device identities, and existing mounts against the actual hardware;
    do not infer them from an old configuration or a pool name alone.
    The NVMe and bulk storage may use Btrfs, older ZFS pools, or a mixture
    during migration. An OS disk may also contain home directories and history.
    Never run disko in format/destroy mode, wipefs, mkfs, zpool create, or any
    command that recreates an existing filesystem or pool.

    Inspect existing filesystems read-only before planning any writes. An
    authorized Btrfs inspection mount needs ro,rescue=nologreplay. Add subvolid=5
    only when explicitly inspecting the filesystem top level. ro alone can
    replay the tree log. Inspect ZFS discovery with zpool import, then use
    verified pool identities for any separately authorized read-only imports.
    Preserve Btrfs subvolumes and snapshots, ZFS datasets and snapshots, home
    data, installed SSH host keys, secrets, service state, and existing history.
    Reinstall into the existing mounted filesystems, without repartitioning.
    Before authorized installation writes, snapshot affected subvolumes or
    datasets and retain the previous system generation and EFI boot files.

    Verify UEFI boot, the actual EFI partition, and its installed mountpoint
    before repairing a bootloader. Do not reboot until the installed system
    profile and boot entries have been checked.
  '';
}
