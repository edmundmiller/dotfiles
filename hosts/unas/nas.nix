{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  join = lib.concatStringsSep " ";
  shares = [
    "/data/media/books/audiobooks"
    "/data/media/books/ebooks"
    "/data/docs"
    "/data/media/downloads"
    "/data/media/video/shows"
    "/data/media/video/movies"
    "/data/media/music"
    "/data/media/photos"
  ];
  bulkDevice = config.fileSystems."/data".device;
  bulkMounts = lib.filterAttrs (_: fs: fs.device == bulkDevice) config.fileSystems;
  mountUnits = map (path: "${utils.escapeSystemdPath path}.mount") (lib.attrNames bulkMounts);
  bulkDependency = {
    requires = [ "unas-bulk-ready.service" ];
    after = [ "unas-bulk-ready.service" ];
    bindsTo = [ "unas-bulk-ready.service" ];
  };

  allowIpRanges = [
    "100.64.0.0/10" # Tailscale
    "192.168.1.0/24" # Home LAN
  ];

  # A filesystem rewrite changes implicit NFS identities; clients must remount once.
  fsExports = lib.imap1 (id: fs: ''
    ${fs} ${
      join (map (r: "${r}(rw,sync,no_subtree_check,root_squash,fsid=${toString id})") allowIpRanges)
    }
  '') shares;
in
{
  assertions = map (path: {
    assertion = lib.hasAttr path bulkMounts;
    message = "UNAS NFS share ${path} must have its own bulk filesystem mount.";
  }) shares;

  systemd.services = {
    unas-bulk-ready = {
      description = "Verify UNAS bulk filesystem and subvolume identities";
      requires = mountUnits;
      after = mountUnits;
      bindsTo = mountUnits;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          path: fs:
          let
            subvolume = lib.findFirst (lib.hasPrefix "subvol=") "subvol=" fs.options;
            fsRoot =
              if builtins.elem "subvolid=5" fs.options then "/" else "/${lib.removePrefix "subvol=" subvolume}";
            expected = "${lib.removePrefix "/dev/disk/by-uuid/" bulkDevice} btrfs ${fsRoot}";
          in
          ''
            actual=$(${pkgs.util-linux}/bin/findmnt --noheadings --raw --mountpoint ${lib.escapeShellArg path} --output UUID,FSTYPE,FSROOT)
            if [ "$actual" != ${lib.escapeShellArg expected} ]; then
              echo ${lib.escapeShellArg "Refusing bulk access: wrong filesystem or subvolume at ${path}"} >&2
              exit 1
            fi
          ''
        ) bulkMounts
      );
    };
    nfs-server = bulkDependency // {
      # Never export empty directories on the OS disk when a data mount fails.
      unitConfig.RequiresMountsFor = shares;
    };
    nfs-mountd = bulkDependency;
    netatalk = bulkDependency;
  };

  # Match the export allowlist instead of exposing NFS on every source network.
  networking.firewall.extraCommands = lib.concatMapStringsSep "\n" (range: ''
    iptables -A nixos-fw -p tcp -s ${range} --dport 2049 -j nixos-fw-accept
  '') allowIpRanges;
  networking.firewall.extraStopCommands = lib.concatMapStringsSep "\n" (range: ''
    iptables -D nixos-fw -p tcp -s ${range} --dport 2049 -j nixos-fw-accept || true
  '') allowIpRanges;

  # Daemon
  services.nfs.server = {
    enable = true;
    createMountPoints = false;
    # exported shares
    exports = lib.concatStringsSep "" fsExports;
  };
}
