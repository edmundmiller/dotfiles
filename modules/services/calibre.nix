{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.services.calibre = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.calibre.enable {
    services.calibre-server.enable = true;
    services.calibre-server.libraryDir = "/home/emiller/library";
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}
