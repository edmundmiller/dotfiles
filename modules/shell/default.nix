{ config, lib, pkgs, ... }:

{
  imports = [
    ./direnv.nix
    ./git.nix
    ./gnupg.nix
    ./mail.nix
    ./ncmpcpp.nix
    ./pass.nix
    ./ranger.nix
    ./tmux.nix
    ./zsh.nix
  ];
}
