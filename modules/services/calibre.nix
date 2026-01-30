{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.calibre;
in
{
  options.modules.services.calibre = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service
  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {
      services.calibre-server.enable = true;
      services.calibre-server.libraries = [ "/home/emiller/calibre" ];

      networking.firewall.allowedTCPPorts = [ 8080 ];
    }
  );
}
