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

    SSH accepts only the supplied public keys. Console login needs no password.
    No NAS pool is imported and no disk is formatted automatically.
    Read /etc/unas-recovery.txt before reinstalling.
  '';

  environment.etc."unas-recovery.txt".text = ''
    UNAS data-preserving reinstall

    This USB boots a live system with Ethernet DHCP, SSH, and ZFS tools.
    It does not reinstall, partition, format, or import pools automatically.

    First inspect lsblk -f, /dev/disk/by-id, and zpool import.
    The configured OS disk is nvme-PCIe_SSD_20092410240085.
    Confirm it against the actual hardware; do not trust an old configuration.
    zroot contains /home as well as the OS. Preserve both zroot and datatank.
    Never run disko in format/destroy mode, wipefs, mkfs, or zpool create.

    Inspect existing pools read-only before planning any writes. Keep the
    installed SSH host keys, secrets, home datasets, and service state.
    Reinstall into the existing mounted filesystems, without repartitioning.
    Snapshot affected datasets and retain the previous system generation
    before installing a replacement generation or repairing the bootloader.

    The existing machine uses /boot as its EFI mountpoint. Verify UEFI boot
    and the actual partition before installing a bootloader. Do not reboot
    until the installed system profile and boot entries have been checked.
  '';
}
