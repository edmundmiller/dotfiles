{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.desktop.gnome;
in {
  options.modules.desktop.gnome = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    programs.dconf.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
      gnome.adwaita-icon-theme
    ];

    # Throws an error without
    hardware.pulseaudio.enable = false;
  };
}
