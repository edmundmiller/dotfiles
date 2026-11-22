{ pkgs, ... }:
let
  home = "/var/lib/amp-orbs";
  note4cNode = pkgs.writeShellApplication {
    name = "amp-note4c-node";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = builtins.readFile ../../config/amp-orbs/note4c-node.sh;
  };
  djiCaptureBroker = pkgs.writeShellApplication {
    name = "amp-dji-capture-broker";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${../../config/amp-orbs/dji-capture-broker.py}
    '';
  };
in
{
  imports = [ ../_amp-orbs.nix ];

  # One physical Note 4C, one household agent thread. Do not grant dialout membership
  # or expose the Nabu Casa ZBT-2 (303a:831a) used by Home Assistant.
  environment.etc."amp-orbs/note4c-orb".text = ''
    amp-01a1f05a-2cb2-73dc-ab1d-7f51b1b4f508
  '';
  # Independent capture grant for the feedback-loop thread. No control/mixer,
  # playback, whole USB bus, or transfer of the Note4C serial grant.
  environment.etc."amp-orbs/dji-capture-orb".text = ''
    amp-01a1fc7c-f023-7099-bc09-aeec0b45eb37
  '';
  environment.etc."note4c/headset-bench.py".source = ../../config/amp-orbs/headset-bench.py;
  environment.etc."note4c/shared-controller.py".source = ../../config/amp-orbs/shared-controller.py;

  # No board access. Instances quiet/tone preserve the current gains and boost.
  systemd.services."note4c-headset-probe@" = {
    description = "Aggregate-only headset capture probe (%i)";
    restartIfChanged = false;
    path = [ pkgs.alsa-utils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --probe-%i";
      ExecStopPost = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --restore";
      StateDirectory = "note4c-headset";
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = 120;
      TimeoutStopSec = 120;
      KillMode = "control-group";
      DevicePolicy = "closed";
      DeviceAllow = [ "char-alsa rw" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      LimitCORE = 0;
      CoredumpFilter = "0x0";
      MemorySwapMax = 0;
      MemoryMax = "128M";
    };
  };

  # Explicit one-shot tests only. No timer, listener, raw audio grant or boot run.
  # The trusted host service restores mixer state even after its main process dies.
  systemd.services.note4c-headset-calibration = {
    description = "Bounded local-only Note4C headset calibration";
    restartIfChanged = false;
    path = [ pkgs.alsa-utils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --calibrate";
      ExecStopPost = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --restore";
      StateDirectory = "note4c-headset";
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = 25;
      # Up to 13 inspection reads at 5s, then 12 restore calls at 3s.
      # This does not extend the recorder's independent 8s kill deadline.
      TimeoutStopSec = 120;
      KillMode = "control-group";
      DevicePolicy = "closed";
      DeviceAllow = [ "char-alsa rw" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      LimitCORE = 0;
      CoredumpFilter = "0x0";
      MemorySwapMax = 0;
      MemoryMax = "128M";
    };
  };

  # The host coordinator uses rootless Podman outside this sandbox. The bench
  # accepts its root-only connection during an explicit, finite invocation.
  # Both services use the same durable lock, budget and recovery snapshot.
  systemd.services.note4c-independent-paths = {
    description = "Two reserved independent Note4C acoustic path measurements";
    restartIfChanged = false;
    path = [ pkgs.alsa-utils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --shared";
      ExecStopPost = "${pkgs.python3}/bin/python3 ${../../config/amp-orbs/headset-bench.py} --restore";
      StateDirectory = "note4c-headset";
      StateDirectoryMode = "0700";
      RuntimeDirectory = "note4c-headset";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = 300;
      TimeoutStopSec = 120;
      KillMode = "control-group";
      DevicePolicy = "closed";
      DeviceAllow = [ "char-alsa rw" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      LimitCORE = 0;
      CoredumpFilter = "0x0";
      MemorySwapMax = 0;
      MemoryMax = "128M";
    };
  };

  # A stable, root-owned devtmpfs directory allows hotplug without binding /dev.
  systemd.tmpfiles.rules = [
    "d /dev/amp-note4c-port 0750 root amp-orbs -"
    "d /run/amp-dji-capture 0750 root amp-orbs -"
  ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", ATTRS{serial}=="80:45:6B:37:55:E8", OWNER:="amp-orbs", GROUP:="amp-orbs", MODE:="0660", SYMLINK+="amp-note4c", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{AMP_NOTE4C}="1", RUN+="${note4cNode}/bin/amp-note4c-node add %M %m"
    ACTION=="remove", SUBSYSTEM=="tty", ENV{AMP_NOTE4C}=="1", RUN+="${note4cNode}/bin/amp-note4c-node remove %M %m"
  '';

  # No reusable ALSA node is exposed to the orb. A disconnected open handle
  # fails rather than following a recycled major/minor to another sound card.
  systemd.sockets.amp-dji-capture = {
    description = "Approved DJI capture handle requests (no audio recording)";
    wantedBy = [ "sockets.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    listenStreams = [ "/run/amp-dji-capture/capture.sock" ];
    socketConfig = {
      Accept = true;
      SocketUser = "root";
      SocketGroup = "amp-orbs";
      SocketMode = "0660";
      DirectoryMode = "0750";
      MaxConnections = 1;
    };
  };
  systemd.services."amp-dji-capture@" = {
    description = "Pass one verified DJI capture handle";
    serviceConfig = {
      ExecStart = "${djiCaptureBroker}/bin/amp-dji-capture-broker";
      StandardInput = "socket";
      StandardOutput = "socket";
      StandardError = "journal";
      DynamicUser = true;
      SupplementaryGroups = [ "audio" ];
      DevicePolicy = "closed";
      DeviceAllow = [ "char-alsa rw" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RuntimeMaxSec = 5;
      TimeoutStopSec = 1;
    };
  };

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
        zfs create -o mountpoint=${home} -o quota=175G "$dataset"
      fi
      test "$(zfs get -H -o value mountpoint "$dataset")" = ${home}
      test "$(zfs get -H -p -o value quota "$dataset")" = 187904819200
      test "$(zfs get -H -o value mounted "$dataset")" = yes
      chown amp-orbs:amp-orbs ${home}
      chmod 0700 ${home}
    '';
  };
}
