{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.hardware.sensors;
in
{
  options.modules.hardware.sensors = {
    enable = mkBoolOpt false;
  };

  config = mkNixOSOnlyConfig isDarwin "modules.hardware.sensors" cfg.enable {
    user.packages = [ pkgs.lm_sensors ];
  };
}
