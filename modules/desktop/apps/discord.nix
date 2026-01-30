{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.discord;
in
{
  options.modules.desktop.apps.discord = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # If not installed from unstable, Discord will sometimes soft-lock itself
      # on a "there's an update for discord" screen.
      unstable.beeper
      unstable.discord
      unstable.teams-for-linux
      slack
      unstable.element-desktop
      unstable.zoom-us
    ];
  };
}
