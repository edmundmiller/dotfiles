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
      gnomeExtensions.appindicator
      gnome.adwaita-icon-theme
      # Material-shell
      plata-theme
      tela-icon-theme
    ];

    # Systray Icons
    services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];

    # Throws an error without
    hardware.pulseaudio.enable = false;
  };
}
