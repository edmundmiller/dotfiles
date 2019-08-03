{ config, lib, pkgs, ... }:

# This is for packages that didn't require configuring and would be installed on a desktop
{
  imports = [ ./base.nix ];
  environment.systemPackages = with pkgs; [
    # BROWSERS
    brave
    # FIXME qutebrowser
    firefox
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
    spotify
    obs-studio
    screenkey
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
