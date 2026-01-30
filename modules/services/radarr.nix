{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.radarr;
in
{
  options.modules.services.radarr = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.radarr.enable = true;
    services.radarr.openFirewall = true;
  };
}
