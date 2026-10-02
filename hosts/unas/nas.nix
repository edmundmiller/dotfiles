{ config, lib, ... }:
let
  join = lib.concatStringsSep " ";
  isMounted = path: lib.hasAttr path config.fileSystems;

  fileSystems = lib.filter isMounted [
    "/data/media/books/audiobooks"
    "/data/media/books/ebooks"
    "/data/docs"
    "/data/media/downloads"
    "/data/media/video/shows"
    "/data/media/video/movies"
    "/data/media/video/music"
    "/data/media/video/photos"
  ];

  allowIpRanges = [
    "100.64.0.0/10" # Tailscale
    "192.168.1.0/24" # Home LAN
  ];

  # Tempalte NFS config
  fsExports = map (fs: ''
    ${fs} ${join (map (r: "${r}(rw,no_subtree_check)") allowIpRanges)}
  '') fileSystems;
in
{
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
    createMountPoints = true;
    # exported shares
    exports = lib.concatStringsSep "" fsExports;
  };
}
