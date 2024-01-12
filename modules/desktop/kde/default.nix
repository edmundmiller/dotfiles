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
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.plasma5.enable = true;
    services.xserver.desktopManager.plasma5.useQtScaling = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      wl-clipboard
    ];

    hardware.nvidia.modesetting.enable = true;

    # programs.firefox.nativeMessagingHosts.gsconnect = true;
    programs.kdeconnect.enable = true;
  };
}
