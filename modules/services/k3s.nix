{
  options,
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.k3s;
in {
  options.modules.services.k3s = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.k3s = {
      enable = true;
      package = pkgs.unstable.k3s;
      role = "agent";
      docker = false;
      serverAddr = "https://192.168.1.123:6443";
      tokenFile = /home/emiller/.tokenfile;
      extraFlags = toString [
        "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
      ];
    };

    virtualisation.containerd.enable = true;
    virtualisation.containerd.settings = {
      plugins.cri.cni = {bin_dir = "/opt/cni/bin/";};
    };
    systemd.services.containerd.serviceConfig = {
      ExecStartPre = [
        "-${pkgs.zfs}/bin/zfs create -o mountpoint=/var/lib/containerd/io.containerd.snapshotter.v1.zfs tank/containerd"
      ];
    };

    # Ceph
    boot.kernelModules = ["ceph" "rbd"];
    environment.systemPackages = [pkgs.lvm2];
    networking.firewall.enable = false;

    user.extraGroups = ["568"];
  };
}
