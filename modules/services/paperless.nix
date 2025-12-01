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
  cfg = config.modules.services.paperless;
in
{
  options.modules.services.paperless = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    services.paperless.enable = true;

    networking.firewall.allowedTCPPorts = [ 28981 ];
  });
}
