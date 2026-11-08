{
  pkgs,
  inputs,
  fileSystems,
}:
let
  inherit (pkgs) lib;
  bulkDevice = fileSystems."/data".device;
  bulkMounts = lib.filterAttrs (_: fs: fs.device == bulkDevice) fileSystems;
  uuid = lib.removePrefix "/dev/disk/by-uuid/" bulkDevice;
  subvolumes = lib.unique (
    lib.concatMap (
      fs: map (lib.removePrefix "subvol=") (lib.filter (lib.hasPrefix "subvol=") fs.options)
    ) (lib.attrValues bulkMounts)
  );
in
(import ../../../lib { inherit pkgs inputs lib; }).mkServiceVmTest {
  name = "unas-late-bulk";
  modules = [
    ../nas.nix
    ../modules/time-machine.nix
  ];
  extraConfig = {
    users.users.monimiller = {
      isNormalUser = true;
      uid = 1001;
    };
    services.openssh.enable = true;
    boot.kernelModules = [ "loop" ];
    environment.systemPackages = [
      pkgs.btrfs-progs
      pkgs.util-linux
    ];
    virtualisation.fileSystems = bulkMounts;
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")
    machine.wait_until_succeeds("journalctl -b | grep -F 'Timed out waiting for device'", timeout=60)
    machine.fail("systemctl is-active nfs-server.service")
    machine.fail("systemctl is-active netatalk.service")
    machine.succeed("test ! -e /data/backup/moni/time-machine")
    machine.succeed("truncate -s 512M /tmp/bulk.img; mkfs.btrfs -f -U ${uuid} /tmp/bulk.img")
    machine.succeed("mkdir /tmp/prepare; mount -o loop /tmp/bulk.img /tmp/prepare")
    machine.succeed("${
      lib.concatMapStringsSep "; " (name: "btrfs subvolume create /tmp/prepare/${name}") subvolumes
    }")
    machine.succeed("umount /tmp/prepare; losetup --find --show /tmp/bulk.img; udevadm settle")
    machine.wait_until_succeeds("systemctl is-active nfs-server.service", timeout=120)
    machine.wait_for_unit("netatalk.service", timeout=120)
    machine.succeed("mountpoint /data/docs; exportfs -v | grep -F /data/docs")
    machine.succeed('test "$(stat -c %u:%g:%a /data/backup/moni/time-machine)" = 1001:100:700')
    pid = machine.succeed("systemctl show -p MainPID --value netatalk.service").strip()
    machine.succeed("systemctl start unas-share-recovery.service")
    assert machine.succeed("systemctl show -p MainPID --value netatalk.service").strip() == pid
    machine.succeed("mount -t tmpfs tmpfs /data/docs; systemctl stop unas-bulk-ready.service")
    machine.succeed("systemctl start unas-share-recovery.service")
    machine.wait_until_succeeds("journalctl -b -u unas-bulk-ready | grep -F 'Refusing bulk access'", timeout=30)
    machine.fail("systemctl is-active nfs-server.service")
    machine.fail("systemctl is-active netatalk.service")
    machine.wait_for_unit("sshd.service")
  '';
}
