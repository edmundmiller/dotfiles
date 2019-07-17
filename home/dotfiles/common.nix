{ config, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  # doom = pkgs.fetchFromGitHub {
  #   owner = "syl20bnr";
  #   repo = "spacemacs";
  #   rev = "4b195ddfc9228256361e0b264fe974aa86ed51a8";
  #   sha256 = "0n7a05j10d5gn0423jwr16ixlhz0dv1d5bbzcf5k4h916d77ycbl";
  # };
  # doomPrivate = pkgs.fetchFromGitHub {
  #   owner = "syl20bnr";
  #   repo = "spacemacs";
  #   rev = "4b195ddfc9228256361e0b264fe974aa86ed51a8";
  #   sha256 = "0n7a05j10d5gn0423jwr16ixlhz0dv1d5bbzcf5k4h916d77ycbl";
  # };
in {

  # home.file.".emacs.d" = { source = doom;
  # recusive = true;
  # }
  home.sessionVariables = { EDITOR = "emacs"; };
  # home.keyboard.options = "caps:escape";

  # xdg.configFile = {
  #   # link recursively so other modules can link files in this folder,
  #   # particularly in zsh/rc.d/*.zsh
  #   "zsh" = {
  #     recursive = true;
  #   };
  #   "doom" = {
  #     source = doomPrivate;
  #     recursive = true;
  #   };
  # };
}
