{ pkgs, utils, ... }:
let
  home = "/var/lib/amp-orbs";
  backing = "/.btrfs/@amp-orbs";
  image = "${backing}/storage.ext4";
  bytes = "68719476736";
  mountUnit = "${utils.escapeSystemdPath home}.mount";
in
{
  imports = [ ../_amp-orbs.nix ];

  # A sibling subvolume stays outside Btrbk's @root/@home/@var snapshots.
  # A preallocated image bounds writes without enabling filesystem-wide qgroups.
  systemd.services.amp-orb-storage-prepare = {
    description = "Prepare bounded local UNAS orb storage";
    # The dependent mount runs before local-fs.target. Avoid a basic.target cycle.
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = [
        "/.btrfs"
        "/nix/store"
      ];
    };
    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.e2fsprogs
      pkgs.findutils
      pkgs.gawk
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -euo pipefail
      actual=$(findmnt --noheadings --raw --mountpoint /.btrfs --output UUID,FSTYPE,FSROOT)
      test "$actual" = '89097bd0-010c-4b38-b618-eeac591a617c btrfs /'
      test ! -L ${backing} && test ! -L ${home}
      # Refuse to hide existing state before creating or allocating anything.
      if ! mountpoint -q ${home} && [ -d ${home} ]; then
        test -z "$(find ${home} -mindepth 1 -print -quit)"
      fi
      if ! btrfs subvolume show ${backing} >/dev/null 2>&1; then
        test ! -e ${backing}
        btrfs subvolume create ${backing}
      fi
      chown root:root ${backing}
      chmod 0700 ${backing}
      if [ ! -e ${image} ]; then
        # Do not overwrite unrelated data or adopt an interrupted preparation.
        test -z "$(find ${backing} -mindepth 1 -print -quit)"
        available=$(df -Pk ${backing} | awk 'END {print $4}')
        test "$available" -ge 104857600
        temporary=$(mktemp ${backing}/.storage.XXXXXX)
        trap 'rm -f "$temporary"' EXIT
        # Set NOCOW before allocation; never discard the reserved extents.
        chattr +C "$temporary"
        fallocate --length ${bytes} "$temporary"
        mkfs.ext4 -q -m 0 -L amp-orbs -E nodiscard,lazy_itable_init=0,lazy_journal_init=0 "$temporary"
        sync -f "$temporary"
        mv -T "$temporary" ${image}
        sync -f ${backing}
        trap - EXIT
      fi
      test -f ${image} && test ! -L ${image}
      test "$(stat -c %s ${image})" = ${bytes}
      test "$(blkid -p -s TYPE -o value ${image})" = ext4
      test "$(blkid -p -s LABEL -o value ${image})" = amp-orbs
    '';
  };

  systemd.mounts = [
    {
      what = image;
      where = home;
      type = "ext4";
      options = "loop,noatime";
      requires = [ "amp-orb-storage-prepare.service" ];
      after = [ "amp-orb-storage-prepare.service" ];
    }
  ];

  systemd.services.amp-orb-storage = {
    description = "Verify bounded UNAS orb storage";
    wantedBy = [ "multi-user.target" ];
    requires = [ mountUnit ];
    after = [ mountUnit ];
    path = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      test "$(findmnt --noheadings --raw --mountpoint ${home} --output FSTYPE,LABEL)" = 'ext4 amp-orbs'
      loop=$(findmnt --noheadings --raw --mountpoint ${home} --output SOURCE)
      test "$(losetup --noheadings --raw --output BACK-FILE "$loop")" = ${image}
      chown amp-orbs:amp-orbs ${home}
      chmod 0700 ${home}
    '';
  };
}
