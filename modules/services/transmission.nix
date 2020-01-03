{ config, lib, pkgs, ... }:

{
  users.users.emiller.extraGroups = [ "transmission" ];

  services.transmission = {
    enable = true;
    settings = {
      download-dir = "/home/emiller/torrents";
      incomplete-dir = "/home/emiller/torrents/.incomplete";
      incomplete-dir-enabled = true;
      rpc-whitelist = "127.0.0.1,192.168.*.*,10.0.0.*";
      rpc-host-whitelist = "*";
      rpc-host-whitelist-enabled = true;
      ratio-limit = 0;
      ratio-limit-enabled = true;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 51413 ];
    allowedUDPPorts = [ 51413 ];
  };

  systemd.services.transmission = { ... }: {
    options = {
      serviceConfig = lib.mkOption {
        apply = old:
          old // {
            ExecStartPre = pkgs.writeScript "transmission-pre-start-two" ''
              #!${pkgs.runtimeShell}
               ${old.ExecStartPre}
               chmod 777 /home/emiller/torrents
            '';
          };
      };
    };
  };
}
