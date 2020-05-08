# from https://github.com/illegalprime/nix/blob/1eb90ceaa9af14eba9d10d1178076e428994de0d/nixos/pia-system.nix

{ config, options, pkgs, lib, ... }:

with builtins;
with lib;
let
  pia-config = with pkgs;
    stdenv.mkDerivation rec {
      name = "pia-config";

      buildInputs = [ unzip libuuid ];

      src = fetchurl {
        url = "https://www.privateinternetaccess.com/openvpn/openvpn.zip";
        sha256 = "1idrhhgglybnvb191d3m068xpcmiaxgv66z66w9580m0f2wapff1";
      };

      unpackPhase = ''
        unzip $src
      '';

      installPhase = ''
        mkdir -p "$out/uuids"
        ls *.ovpn | while read FILE; do
          uuidgen --md5 -n @url -N "$FILE" > "$out/uuids/$FILE"
        done
        mkdir -p "$out/config"
        mv *.ovpn "$out/config"
        mkdir -p "$out/certs"
        mv *.crt *.pem "$out/certs"
      '';

      fixupPhase = ''
        sed -i "s|crl.rsa.2048.pem|$out/certs/\0|g" "$out"/config/*.ovpn
        sed -i "s|ca.rsa.2048.crt|$out/certs/\0|g" "$out"/config/*.ovpn
        sed -i "s|auth-user-pass|auth-user-pass ${
          ./pia-login.conf
        }|g" "$out"/config/*.ovpn
      '';
    };
in {
  options.modules.services.pia = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
  config = mkIf config.modules.services.pia.enable {
    environment.systemPackages = with pkgs; [ openresolv ];

    # Configure all our servers
    # Use with `sudo systemctl start openvpn-us-texas`
    services.openvpn.servers = let
      vpn_str = with (import <nixpkgs> { }).lib.strings;
        file:
        removeSuffix ".ovpn" (toLower (replaceStrings [ " " ] [ "-" ] file));
    in foldl' (init: file:
      init // {
        "${vpn_str file}" = {
          config = readFile "${pia-config}/config/${file}";
          # autoStart = (vpn_str file) == "us-texas";
          autoStart = false;
          up =
            "echo nameserver $nameserver | ${pkgs.openresolv}/sbin/resolvconf -m 0 -a $dev";
          down = "${pkgs.openresolv}/sbin/resolvconf -d $dev";
        };
      }) { } (attrNames (readDir "${pia-config}/config"));

    my = {
      alias.piau = "sudo systemctl start openvpn-us-texas";
      alias.piad = "sudo systemctl stop openvpn-us-texas";
    };
  };
}
