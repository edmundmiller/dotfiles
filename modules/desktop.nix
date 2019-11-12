{ config, lib, pkgs, ... }:

# This is for packages that didn't require configuring and would be installed on a desktop
{
  imports = [ ./base.nix ./misc/firefox.nix ];
  environment.systemPackages = with pkgs; [
    aseprite-unfree
    # BROWSERS
    brave
    qutebrowser
    # NIX STUFF
    appimage-run
    # APPS
    atom-beta
    gnucash
    libreoffice-fresh
    keybase-gui
    calibre
    discord
    dropbox
    gimp
    keybase-gui
    xst
    spotify
    obs-studio
    screenkey
    gnome3.nautilus
    transmission
    mpv
    okular
    pavucontrol
    rxvt_unicode
    networkmanagerapplet
    networkmanager_dmenu
    ffmpeg-full
    # FIXME zoom-us
    # CLI
    maim
    graphviz
    dfu-programmer
  ];
}
