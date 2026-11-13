{ pkgs, ... }:
let
  home = "/var/lib/amp-orbs";
in
{
  # Amp's mutable Linux CLI uses the generic ELF loader, not a Nix store loader.
  programs.nix-ld.enable = true;

  # Each host supplies amp-orb-storage.service for its bounded local storage.
  # Never reuse a personal account, host checkout, or rootful Podman socket.
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
    source = ../config/amp-orbs/dispatch.sh;
    mode = "0555";
  };
  environment.etc."amp-orbs/storage.conf".text = ''
    [storage]
    driver = "overlay"
    graphroot = "${home}/.local/share/containers/storage"
    [storage.options.overlay]
    mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
  '';

  # Amp owns its mutable CLI. Authentication remains local to this account.
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

  # Registration and its readiness marker are separate approved operations.
  systemd.user.units."amp-orb-provider.service" = {
    text = builtins.readFile ../config/amp-orbs/provider.service;
    wantedBy = [ "default.target" ];
  };
}
