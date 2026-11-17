{ lib, pkgs, ... }:
let
  mediaSource = "unas.home:/data/media/books/audiobooks";
  mediaDependency = {
    unitConfig.RequiresMountsFor = [ "/audiobooks" ];
    bindsTo = [ "audiobooks.mount" ];
    preStart = lib.mkBefore ''
      actual=$(${pkgs.util-linux}/bin/findmnt --noheadings --raw --mountpoint /audiobooks --output SOURCE,FSTYPE)
      if [ "$actual" != "${mediaSource} nfs4" ]; then
        echo "Refusing audiobook access without the NAS NFS mount" >&2
        exit 1
      fi
    '';
  };
in
{
  # Keep the saved library paths and the separate local application database.
  fileSystems."/audiobooks" = {
    device = mediaSource;
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  # NFS AUTH_SYS uses numeric identities, not the NAS account names.
  users.users.audiobookshelf.uid = 994;
  users.groups.audiobookshelf.gid = 992;

  systemd.services.audiobookshelf = mediaDependency;
  systemd.services.restic-backups-audiobooks = mediaDependency // {
    serviceConfig.SupplementaryGroups = [ "audiobookshelf" ];
  };
}
