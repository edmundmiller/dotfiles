{ config, lib, pkgs, ... }:

# This is a base of packages that didn't need configuring in their own module
{
  imports = [
    ./editors/emacs.nix
    ./shell/direnv.nix
    ./shell/git.nix
    ./shell/ncmpcpp+mpd.nix
    ./shell/gpg.nix
    ./shell/zsh.nix
    ./shell/termite.nix
  ];

  environment.systemPackages = with pkgs; [
    speedtest-cli
    openconnect
    # cachix
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
    autoconf
    automake
    gnutls
    gnumake
    gcc
    ranger
    pb_cli
  ];
}
