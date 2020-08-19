{ config, lib, pkgs, ... }: {
  my.packages = with pkgs; [
    xfce.thunar
    xfce.tumbler # for thumbnails

    cachix
    evince # pdf reader
    sxiv # image viewer
    libreoffice-fresh
    networkmanagerapplet
    networkmanager_dmenu
    openconnect_pa
    speedtest-cli
    xclip
    xdotool
    visidata
    libqalculate # calculator cli w/ currency conversion
    (makeDesktopItem {
      name = "scratch-calc";
      desktopName = "Calculator";
      icon = "calc";
      exec = "scratch '${tmux}/bin/tmux new-session -s calc -n calc qalc'";
      categories = "Development";
    })
  ];

  ## Sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  services = {
    xserver = {
      enable = true;
      layout = "us";
      xkbOptions = "caps:escape";
      libinput = {
        enable = true;
        disableWhileTyping = true;
        tapping = false;
      };
    };
  };

  ## Fonts
  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      ubuntu_font_family
      dejavu_fonts
      fira-code
      fira-code-symbols
      iosevka
      symbola
      noto-fonts
      noto-fonts-cjk
      font-awesome-ttf
      siji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Ubuntu" ];
      monospace = [ "Fira Code" ];
    };
  };

  ## Apps/Services
  # For redshift
  location = (if config.time.timeZone == "America/Chicago" then {
    latitude = 32.98576;
    longitude = -96.75009;
  } else
    { });

  services.xserver = {
    displayManager.lightdm.greeters.mini.user = config.my.username;
  };

  services.compton = {
    backend = "glx";
    vSync = true;
    opacityRules = [
      # "100:class_g = 'Firefox'"
      # "100:class_g = 'Vivaldi-stable'"
      "100:class_g = 'VirtualBox Machine'"
      # Art/image programs where we need fidelity
      "100:class_g = 'Gimp'"
      "100:class_g = 'Inkscape'"
      "100:class_g = 'aseprite'"
      "100:class_g = 'krita'"
      "100:class_g = 'feh'"
      "100:class_g = 'mpv'"
      "100:class_g = 'Rofi'"
      "100:class_g = 'Peek'"
      "100:class_g = 'zoom'"
      "100:_NET_WM_STATE@:32a = '_NET_WM_STATE_FULLSCREEN'"
      # Games
      "100:class_g = 'dota2'"
      "100:class_g = 'Steam'"
      "100:class_g = 'steam'"
      "100:class_g = 'hl2_linux'"
      "100:class_g = 'csgo_linux64'"
      "100:class_g = 'Tabletop Simulator.x86_64'"
      "100:class_g = 'steam_app_252950'"
      "100:class_g = 'steam_app_435150'"
      "100:class_g = 'pitfall.exe'"
      "100:class_g = 'steam_app_464900'"
      "100:name    = 'Hyper Lighter Drifter'"
      "100:class_g = 'steam_app_6060'"
      "100:class_g = 'Wine'"
      "100:class_g = 'steam_app_292030'"
      "100:class_g = 'witcher3.exe'"
      "100:class_g = 'steam_app_65800'"
    ];
    shadowExclude = [
      # Put shadows on notifications, the scratch popup and rofi only
      "! name~='(rofi|scratch|Dunst)$'"
    ];
    settings.blur-background-exclude = [
      "window_type = 'dock'"
      "window_type = 'desktop'"
      "class_g = 'Rofi'"
      "_GTK_FRAME_EXTENTS@:c"
    ];
  };

  # Try really hard to get QT to respect my GTK theme.
  my.env.GTK_DATA_PREFIX = [ "${config.system.path}" ];
  my.env.QT_QPA_PLATFORMTHEME = "gtk2";
  qt5 = {
    style = "gtk2";
    platformTheme = "gtk2";
  };
  services.xserver.displayManager.sessionCommands = ''
    export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
    source "$XDG_CONFIG_HOME"/xsession/*.sh
    xrdb -merge "$XDG_CONFIG_HOME"/xtheme/*
  '';
}
