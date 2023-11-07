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
  imports = [./dconf.nix];

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    environment.gnome.excludePackages =
      (with pkgs; [
        gnome-photos
        gnome-tour
      ])
      ++ (with pkgs.gnome; [
        cheese # webcam tool
        gnome-music
        # gedit # text editor
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
      ]);
    programs.dconf.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
    ];

    # Systray Icons
    services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];

    # Throws an error without
    hardware.pulseaudio.enable = false;

    # Trying to fix graphical errors after standby
    hardware.nvidia.powerManagement.enable = true;
    hardware.nvidia.modesetting.enable = true;

    programs.evolution.enable = true;
    programs.evolution.plugins = [pkgs.evolution-ews];
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
