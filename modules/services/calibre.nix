{
  options,
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.calibre;
  homeDir = config.users.users.${config.user.name}.home;
in
{
  options.modules.services.calibre = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    services.calibre-server.enable = true;
    services.calibre-server.libraries = [ "${homeDir}/calibre" ];

    networking.firewall.allowedTCPPorts = [ 8080 ];
  });
}
