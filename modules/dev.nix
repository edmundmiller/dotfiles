{ config, lib, pkgs, ... }:

{
  imports = [
    ./editors/emacs.nix
    ./shell/git.nix
    ./shell/mail.nix
    ./shell/ncmpcpp+mpd.nix
    # ./shell/tmux.nix
    ./shell/zsh.nix
  ];
}
