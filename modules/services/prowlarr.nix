{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.prowlarr;
in
{
  options.modules.services.prowlarr = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.prowlarr.enable = true;
    services.prowlarr.openFirewall = true;
  };
}
