{ pkgs, ... }:
let
  home = "/var/lib/amp-orbs";
in
{
  # This account owns no host checkouts, credentials, devices, or sudo rights.
  users.groups.amp-orbs = { };
  users.users.amp-orbs = {
    isSystemUser = true;
    group = "amp-orbs";
    inherit home;
    createHome = false;
    autoSubUidGidRange = true;
    linger = true;
    shell = pkgs.bashInteractive;
  };

  environment.etc."amp-orbs/dispatch" = {
    source = ../../config/amp-orbs/dispatch.sh;
    mode = "0555";
  };
  environment.etc."amp-orbs/storage.conf".text = ''
    [storage]
    driver = "overlay"
    graphroot = "${home}/.local/share/containers/storage"
    [storage.options.overlay]
    mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
  '';

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

  # Amp owns its mutable CLI. No personal runner installation is reused.
  systemd.services.amp-orb-cli-install = {
    description = "Install the dedicated Amp orb controller CLI once";
    wantedBy = [ "multi-user.target" ];
    after = [
      "amp-orb-storage.service"
      "network-online.target"
    ];
    requires = [ "amp-orb-storage.service" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${home}/.amp/bin/amp";
    environment.HOME = home;
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.gnutar
      pkgs.gzip
      pkgs.unzip
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "amp-orbs";
      Group = "amp-orbs";
      UMask = "0077";
    };
    script = ''
      set -euo pipefail
      installer=$(mktemp)
      trap 'rm -f "$installer"' EXIT
      curl --fail --silent --show-error --location https://ampcode.com/install.sh -o "$installer"
      bash "$installer"
      test -x "$HOME/.amp/bin/amp"
    '';
  };

  # The marker is written only after provider registration in this account.
  # Merely deploying the host must not reuse another account's Amp login.
  systemd.user.units."amp-orb-provider.service" = {
    text = builtins.readFile ../../config/amp-orbs/provider.service;
    wantedBy = [ "default.target" ];
  };
}
