{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.desktop.apps.slack = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.desktop.apps.slack.enable {
    my.packages = with pkgs; [ unstable.teams slack ];
  };
}
