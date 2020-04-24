{ config, lib, pkgs, ... }:

# This is for packages that didn't require configuring and would be installed on a desktop
{
  my = {
    packages = with pkgs; [
      cachix
      discord # chat
      evince # pdf reader
      sxiv # image viewer
      gnucash
      libreoffice-fresh
      mpv # video player
      networkmanagerapplet
      networkmanager_dmenu
      openconnect_pa
      ranger
      speedtest-cli
      xclip
      xdotool
      visidata
      zotero
    ];
  };

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

  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      ubuntu_font_family
      dejavu_fonts
      fira-code
      fira-code-symbols
      iosevka
      noto-fonts
      symbola
      font-awesome_5
    ];

    fontconfig.defaultFonts = {
      sansSerif = [ "Ubuntu" ];
      monospace = [ "Iosevka" ];
    };
  };

  services.picom = {
    backend = "glx";
    vSync = true;
    opacityRules = [
      "100:class_g = 'Firefox'"
      "100:class_g = 'Vivaldi-stable'"
      "100:class_g = 'VirtualBox Machine'"
      # Art/image programs where we need fidelity
      "100:class_g = 'Gimp'"
      "100:class_g = 'Inkscape'"
      "100:class_g = 'aseprite'"
      "100:class_g = 'krita'"
      "100:class_g = 'feh'"
      "100:class_g = 'mpv'"
      "100:class_g = 'zoom'"
      # Games
      "100:class_g = 'dota2'"
      "100:class_g = 'Steam'"
      "100:class_g = 'steam'"
      "100:class_g = 'hl2_linux'"
      "100:class_g = 'csgo_linux64'"
      "100:class_g = 'Tabletop Simulator.x86_64'"
      "100:class_g = 'steam_app_252950'"
      "100:class_g = 'steam_app_435150'"
    ];
    settings.blur-background-exclude = [
      "window_type = 'dock'"
      "window_type = 'desktop'"
      "_GTK_FRAME_EXTENTS@:c"
    ];
  };
}
