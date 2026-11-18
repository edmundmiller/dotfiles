{ pkgs, inputs }:
let
  dotfilesLib = import ../../../../lib {
    inherit pkgs inputs;
    inherit (pkgs) lib;
  };
  # Public fixture only. The production credential never enters the store.
  webuiFixture = pkgs.writeText "qb-webui-test.json" (
    builtins.toJSON {
      username = "media-test";
      passwordPBKDF2 = "@ByteArray(cWItdm0tdGVzdC1zYWx0IQ==:lk6FVgXLU2DY4HG/RDgym2iOMxv5vy4v0kQQpWq3ZM/InUskbIyvd6gqf+2Cd/HN14sYxTMaHDDFYXOhppNKAw==)";
    }
  );
in
dotfilesLib.mkServiceVmTest {
  name = "qb-vpn-egress";
  modules = [ ../../qb.nix ];
  extraConfig = { lib, ... }: {
    options.user.name = lib.mkOption {
      type = lib.types.str;
      default = "emiller";
    };
    config = {
      users.users.emiller = {
        isNormalUser = true;
        uid = 1000;
        group = "users";
      };
      modules.services.qb = {
        enable = true;
        authKeyFile = "/run/qb-test-auth";
        webuiCredentialsFile = "/run/qb-test-webui";
        mullvadExitNode = "test.mullvad.ts.net";
      };
      environment.etc."qb-webui-test.json".source = webuiFixture;
      systemd.tmpfiles.rules = [
        "f /run/qb-test-auth 0600 root root - unused-test-key"
        "C /run/qb-test-secrets/webui 0400 root root - ${webuiFixture}"
        # Match agenix's runtime symlink, not a plaintext store-file bind.
        "L /run/qb-test-webui - - - - /run/qb-test-secrets/webui"
      ];
      # Exercise the real container without contacting a tailnet or NAS.
      virtualisation.fileSystems."/data/media/downloads" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=0777" ];
      };
      networking.firewall.interfaces = {
        ve-qb.allowedTCPPorts = [
          18080
          18081
        ];
        vpnpeer.allowedTCPPorts = [ 18082 ];
      };
      environment.systemPackages = [ pkgs.python3 ];
      containers.qb.config = {
        environment.systemPackages = [
          pkgs.curl
          pkgs.python3
          pkgs.util-linux
        ];
        services.tailscale.enable = lib.mkForce false;
        systemd.services.qb-tailscale-serve.enable = false;
        systemd.services.qbittorrent = {
          wantedBy = lib.mkForce [ ];
          requires = lib.mkForce [ "nftables.service" ];
          after = lib.mkForce [ "nftables.service" ];
          bindsTo = lib.mkForce [ "nftables.service" ];
          # Only the live Mullvad check is replaced; confinement is unchanged.
          preStart = lib.mkForce "";
        };
      };
    };
  };
  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("container@qb.service")

    def inside(command):
        return "nixos-container run qb -- sh -c " + shlex.quote(command)

    def as_downloader(command):
        return inside("runuser -u qbittorrent -- " + command)

    machine.wait_until_succeeds(inside("systemctl is-active nftables"))
    machine.succeed("mkdir -p /tmp/egress; echo physical > /tmp/egress/marker")
    machine.succeed("python3 -m http.server 18080 --bind 0.0.0.0 --directory /tmp/egress >/tmp/http.log 2>&1 &")
    machine.wait_until_succeeds(inside("curl -fsS http://192.168.150.1:18080/marker | grep -x physical"))

    with subtest("Direct LAN egress is blocked only for the downloader"):
        machine.fail(as_downloader("curl -fsS --max-time 3 http://192.168.150.1:18080/marker"))

    with subtest("A simulated VPN carries IPv4 and IPv6 downloader traffic"):
        machine.succeed('leader=$(machinectl show qb -p Leader --value); ip link add tailscale0 type veth peer name vpnpeer; ip link set tailscale0 netns "$leader"')
        machine.succeed("ip addr add 198.18.0.2/24 dev vpnpeer; ip -6 addr add fd00:51::2/64 dev vpnpeer; ip link set vpnpeer up")
        machine.succeed(inside("ip addr add 198.18.0.1/24 dev tailscale0; ip -6 addr add fd00:51::1/64 dev tailscale0; ip link set tailscale0 up"))
        machine.succeed("mkdir -p /tmp/vpn; echo tunnel > /tmp/vpn/marker; python3 -m http.server 18082 --bind :: --directory /tmp/vpn >/tmp/vpn.log 2>&1 &")
        machine.wait_until_succeeds(as_downloader("curl -fsS --max-time 3 http://198.18.0.2:18082/marker | grep -x tunnel"))
        machine.wait_until_succeeds(as_downloader("curl -gfsS --max-time 3 http://[fd00:51::2]:18082/marker | grep -x tunnel"))

    with subtest("The real WebUI keeps its secret-backed login across restarts"):
        for action in ["start", "restart"]:
            machine.succeed(inside("systemctl " + action + " qbittorrent || { journalctl -b -u qbittorrent --no-pager; exit 1; }"))
            machine.wait_until_succeeds(inside("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8090/api/v2/app/version) = 403"))
            machine.succeed(inside("test $(curl -sS -o /dev/null -w '%{http_code}' --data 'username=media-test&password=wrong' http://127.0.0.1:8090/api/v2/auth/login) = 401"))
            machine.succeed(inside("curl -fsS -c /tmp/qb-cookie --data 'username=media-test&password=qb-vm-password' http://127.0.0.1:8090/api/v2/auth/login -o /dev/null"))
            machine.succeed(inside("test $(curl -sS -b /tmp/qb-cookie -o /dev/null -w '%{http_code}' http://127.0.0.1:8090/api/v2/app/version) = 200"))
        machine.fail("curl -fsS --max-time 3 http://192.168.150.2:8090/")

    with subtest("Invalid WebUI credentials prevent downloader startup"):
        machine.succeed(inside("systemctl stop qbittorrent"))
        machine.succeed("printf '{}' > /run/qb-test-webui")
        machine.fail(inside("systemctl start qbittorrent"))
        machine.succeed("cat /etc/qb-webui-test.json > /run/qb-test-webui")
        machine.succeed(inside("systemctl start qbittorrent"))

    with subtest("VPN loss cannot fall back to an otherwise working physical route"):
        machine.succeed(inside("ip link del tailscale0"))
        machine.succeed("ip addr add 198.18.0.2/32 dev lo; ip -6 addr add fd00:51::2/128 dev ve-qb")
        machine.succeed("python3 -m http.server 18081 --bind :: --directory /tmp/egress >/tmp/http6.log 2>&1 &")
        machine.succeed(inside("ip route add 198.18.0.2/32 via 192.168.150.1; ip -6 addr add fd00:51::3/64 dev eth0"))
        machine.wait_until_succeeds(inside("curl -fsS --max-time 3 http://198.18.0.2:18080/marker | grep -x physical"))
        machine.wait_until_succeeds(inside("curl -gfsS --max-time 3 http://[fd00:51::2]:18081/marker | grep -x physical"))
        machine.fail(as_downloader("curl -fsS --max-time 3 http://198.18.0.2:18080/marker"))
        machine.fail(as_downloader("curl -gfsS --max-time 3 http://[fd00:51::2]:18081/marker"))

    with subtest("Stopping the firewall stops qBittorrent first"):
        machine.succeed(inside("systemctl stop nftables"))
        machine.fail(inside("systemctl is-active qbittorrent"))

    with subtest("Storage loss stops the container and prevents an unmounted restart"):
        machine.succeed("systemctl stop data-media-downloads.mount")
        machine.fail("systemctl is-active container@qb")
        machine.succeed("systemctl mask --runtime data-media-downloads.mount")
        machine.fail("systemctl start container@qb")
  '';
}
