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
  cfg = config.modules.desktop.apps.audioPriorityBar;
in
{
  options.modules.desktop.apps.audioPriorityBar = {
    enable = mkBoolOpt false;
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      user.packages = [ pkgs.my.audio-priority-bar ];
    }
  );
}
