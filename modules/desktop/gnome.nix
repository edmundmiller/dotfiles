{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.gnome;
in
{
  options.modules.desktop.gnome = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.displayManager.gdm.wayland = true;
    services.xserver.desktopManager.gnome.enable = true;
    services.xserver.desktopManager.gnome.debug = true;
    environment.gnome.excludePackages =
      (with pkgs; [
        gnome-photos
        gnome-tour
        cheese # webcam tool
        gnome-music
        epiphany # web browser
        geary # email reader
        gnome-characters
        tali # poker game
        iagno # go game
        hitori # sudoku game
        atomix # puzzle game
        yelp # Help view
        gnome-contacts
        gnome-initial-setup
      ])
      ++ (with pkgs.gnome; [
        # gedit # text editor
      ]);
    programs.dconf.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
      wl-clipboard
    ];

    hardware.nvidia.modesetting.enable = true;

    # Systray Icons
    services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    # Throws an error without
    hardware.pulseaudio.enable = false;

    programs.evolution.enable = true;
    programs.evolution.plugins = [ pkgs.evolution-ews ];
    # https://nixos.wiki/wiki/GNOME/Calendar
    services.gnome.evolution-data-server.enable = true;
    # optional to use google/nextcloud calendar
    services.gnome.gnome-online-accounts.enable = true;
    # optional to use google/nextcloud calendar
    services.gnome.gnome-keyring.enable = true;

    # programs.firefox.nativeMessagingHosts.gsconnect = true;
    programs.kdeconnect.enable = true;
    programs.kdeconnect.package = pkgs.gnomeExtensions.gsconnect;
  };
}
