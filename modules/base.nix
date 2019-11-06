{ config, lib, pkgs, ... }:

# This is a base of packages that didn't need configuring in their own module
{
  environment.systemPackages = with pkgs; [
    speedtest-cli
    openconnect
    cachix
    # NIX STUFF
    # CLI
    visidata
    youtube-dl
    xclip
    unzip
    slop
    nmap
    borgbackup
    bat
    binutils
    ranger
    pb_cli
  ];
}
