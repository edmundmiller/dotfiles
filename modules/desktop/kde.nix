{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.desktop.kde;
in {
  options.modules.desktop.kde = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.sddm.enable = true;
    services.xserver.desktopManager.plasma5.enable = true;
    programs.dconf.enable = true;
    services.xserver.displayManager.defaultSession = "plasmawayland";
  };
}
