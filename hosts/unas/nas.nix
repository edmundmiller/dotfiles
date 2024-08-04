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
    # "10.2.2.0/8" # Zerotier VPNC
    "192.168.1.0/8" # Local Network
  ];

  # Tempalte NFS config
  fsExports = map (fs: ''
    ${fs} ${join (map (r: "${r}(rw,no_subtree_check)") allowIpRanges)}
  '') fileSystems;
in
{
  # Firewall
  # networking.firewall.interfaces."zt*".allowedTCPPorts = [ 111 2049 4000 4001 4002 ];
  # networking.firewall.interfaces."zt*".allowedUDPPorts = [ 111 2049 4000 4001 4002 ];
  networking.firewall.allowedTCPPorts = [ 2049 ];

  # Daemon
  services.nfs.server = {
    enable = true;
    createMountPoints = true;
    # exported shares
    exports = lib.concatStringsSep "" fsExports;
  };
}
