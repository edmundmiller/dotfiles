{ config, lib, pkgs, ... }:

{
  imports = [
    ./editors/emacs.nix
    ./shell/git.nix
    ./shell/mail.nix
    ./shell/ncmpcpp+mpd.nix
    # ./shell/tmux.nix
    ./shell/gpg.nix
    ./shell/zsh.nix

    ./misc/docker.nix
    ./misc/virtualbox.nix
  ];
}
