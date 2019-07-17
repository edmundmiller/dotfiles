# modules/shell.nix
{ config, pkgs, libs, ... }:

let zgen = builtins.fetchTarball "https://github.com/tarjoilija/zgen/archive/master.tar.gz";
in {
    home.sessionVariables = {
      ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
      ZSH_CACHE = "$XDG_CACHE_HOME/zsh";
      ZGEN_DIR  = "$XDG_CACHE_HOME/zgen";
      ZGEN_SOURCE = "${zgen}/zgen.zsh";
    };

    home.packages = with pkgs; [
      zsh
      nix-zsh-completions
      fasd
      exa
      fd
      tmux
    ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableGlobalCompInit = false; # I'll do it myself
    promptInit = "";
  };
}
