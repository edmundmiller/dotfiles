{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.sonarr;
in
{
  options.modules.services.sonarr = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.sonarr.enable = true;
    services.sonarr.openFirewall = true;
  };
}
