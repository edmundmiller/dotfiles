{ config, lib, pkgs, ... }:

with lib; {
  options.modules.services.keybase = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.keybase.enable {
    my.packages = [ pkgs.keybase-gui ];
    services.kbfs = {
      enable = true;
      mountPoint = "%t/kbfs";
      extraFlags = [ "-label %u" ];
    };

    systemd.user.services.kbfs = {
      environment = { KEYBASE_RUN_MODE = "prod"; };
      serviceConfig.Slice = "keybase.slice";
    };
  };
}
