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
    environment.gnome.excludePackages =
      (with pkgs; [
        gnome-photos
        gnome-tour
      ])
      ++ (with pkgs.gnome; [
        cheese # webcam tool
        gnome-music
        gedit # text editor
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

    env.GTK_THEME = "palenight";
    home-manager.users.emiller = {
      ## GTK
      gtk = {
        enable = true;

        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };

        theme = {
          name = "palenight";
          package = pkgs.palenight-theme;
        };

        cursorTheme = {
          name = "Numix-Cursor";
          package = pkgs.numix-cursor-theme;
        };

        gtk3.extraConfig = {
          Settings = ''
            gtk-application-prefer-dark-theme=1
          '';
        };

        gtk4.extraConfig = {
          Settings = ''
            gtk-application-prefer-dark-theme=1
          '';
        };
      };

      ## dconf
      dconf.settings = {
        "org/gnome/shell" = {
          favorite-apps = [
            "firefox.desktop"
            "emacs.desktop"
            "kitty.desktop"
            "beeper.desktop"
          ];
        };
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = false;
        };
        "org/gnome/desktop/wm/preferences" = {
          workspace-names = ["Web" "Editor" "Terminal" "Chat" "Scratch"];
        };
        # TODO Add number of workspaces

        "org/gnome/shell" = {
          disable-user-extensions = false;

          # `gnome-extensions list` for a list
          enabled-extensions = [
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "trayIconsReloaded@selfmade.pl"
            "Vitals@CoreCoding.com"
            "dash-to-panel@jderose9.github.com"
            "sound-output-device-chooser@kgshank.net"
            "space-bar@luchrioh"
            "gsconnect@andyholmes.github.io"

            # gnome-shell
            "user-theme@gnome-shell-extensions.gcampax.github.com"
          ];

          # FIXME
          # "org/gnome/shell/extensions/user-theme" = {
          #   name = "palenight";
          # };
        };
      };
    };

    user.packages = with pkgs; [
      # ...
      # TODO Add Tailscale
      gnomeExtensions.tray-icons-reloaded
      gnomeExtensions.vitals
      gnomeExtensions.dash-to-panel
      gnomeExtensions.sound-output-device-chooser
      gnomeExtensions.space-bar
      gnomeExtensions.gsconnect
      # gnome-shell
      gnomeExtensions.user-themes
      palenight-theme
    ];
  };
}
