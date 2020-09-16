{ config, options, lib, pkgs, ... }:
with lib; {
  imports = [ ./common.nix ];

  options.modules.desktop.gnome = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.desktop.gnome.enable {
    environment.systemPackages = with pkgs; [
      lightdm
      dunst
      libnotify
      gnome-shell-extension-appindicator-32
      gnome3.adwaita-icon-theme
    ];

    services = {
      picom.enable = true;
      redshift.enable = true;
      xserver = {
        enable = true;
        displayManager.defaultSession = "gnome";
        displayManager.lightdm.enable = true;
        displayManager.lightdm.greeters.mini.enable = true;
        desktopManager.gnome3.enable = true;
      };
    };

    services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

    # link recursively so other modules can link files in their folders
    # my.home.xdg.configFile = { };
  };
}
