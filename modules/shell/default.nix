{ config, lib, pkgs, ... }:

{
  imports = [
    ./aerc.nix
    ./direnv.nix
    ./git.nix
    ./gnupg.nix
    ./mail.nix
    ./ncmpcpp.nix
    ./pass.nix
    ./ranger.nix
    ./tmux.nix
    ./yubikey.nix
    ./zsh.nix
  ];
}
