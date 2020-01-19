{ config, lib, pkgs, ... }:

# This is for packages that didn't require configuring and would be installed on a desktop
{
  environment.systemPackages = with pkgs; [
    # BROWSERS
    qutebrowser
    # NIX STUFF
    appimage-run
    # APPS
    atom-beta
    gnucash
    libreoffice-fresh
    keybase-gui
    calibre
    (callPackage <packages/ripcord.nix> { })
    discord
    dropbox
    keybase-gui
    xst
    spotify
    obs-studio
    screenkey
    gnome3.nautilus
    transmission
    mpv
    xdotool
    okular
    pavucontrol
    rxvt_unicode
    networkmanagerapplet
    networkmanager_dmenu
    ffmpeg-full
    redshift
    # CLI
    maim
    graphviz
    dfu-programmer
  ];

  sound.enable = true;
  hardware = {
    pulseaudio = {
      enable = true;
      support32Bit = true;
      package = pkgs.pulseaudioFull;
    };
  };

  services = {
    redshift.enable = true;

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
}
