{ config, lib, pkgs, ... }:

{
  imports = [
    ./editors/emacs.nix
    ./shell/direnv.nix
    ./shell/git.nix
    ./shell/mail.nix
    ./shell/ncmpcpp+mpd.nix
    # ./shell/tmux.nix
    ./shell/gpg.nix
    ./shell/zsh.nix
    ./shell/termite.nix

    ./dev/node.nix
    ./dev/python.nix
    ./dev/clojure.nix
    ./dev/zsh.nix

    ./misc/docker.nix
    ./misc/virtualbox.nix
  ];
}
