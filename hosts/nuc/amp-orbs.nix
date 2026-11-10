{ pkgs, ... }:
let
  home = "/var/lib/amp-orbs";
in
{
  imports = [ ../_amp-orbs.nix ];

  # Bound images, snapshots, checkouts, and CLI state together, off the NAS.
  # Never mount over an existing non-empty home or change an unrelated dataset.
  systemd.services.amp-orb-storage = {
    description = "Bounded local storage for the Amp orb pilot";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    path = [
      pkgs.zfs
      pkgs.coreutils
      pkgs.findutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      dataset=zroot/system/amp-orbs
      if ! zfs list -H -o name "$dataset" >/dev/null 2>&1; then
        if [ -d ${home} ] && [ -n "$(find ${home} -mindepth 1 -print -quit)" ]; then
          echo "Refusing to cover a non-empty Amp orb home" >&2
          exit 1
        fi
        zfs create -o mountpoint=${home} -o quota=64G "$dataset"
      fi
      test "$(zfs get -H -o value mountpoint "$dataset")" = ${home}
      test "$(zfs get -H -p -o value quota "$dataset")" = 68719476736
      test "$(zfs get -H -o value mounted "$dataset")" = yes
      chown amp-orbs:amp-orbs ${home}
      chmod 0700 ${home}
    '';
  };
}
