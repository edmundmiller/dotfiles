{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.keybase;
in
{
  options.modules.services.keybase = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ keybase-gui ];
    services.kbfs = {
      enable = true;
      mountPoint = "%t/kbfs";
      extraFlags = [ "-label %u" ];
    };

    systemd.user.services.kbfs = {
      environment = {
        KEYBASE_RUN_MODE = "prod";
      };
      serviceConfig.Slice = "keybase.slice";
    };
  };
}
