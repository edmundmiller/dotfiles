{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.services.transmission = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.transmission.enable {
    services.transmission = {
      enable = true;
      home = "/data/media/torrents";
      user = config.my.username;
      settings = {
        incomplete-dir-enabled = true;
        rpc-whitelist = "127.0.0.1,192.168.*.*";
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

    my.user.extraGroups = [ "transmission" ];
  };
}
