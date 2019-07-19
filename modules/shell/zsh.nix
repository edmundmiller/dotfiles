{ config, pkgs, libs, ... }:

# TODO Auto magically install plugins with antibody
{
  environment = {
    variables = {
      ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
      ZSH_CACHE = "$XDG_CACHE_HOME/zsh";
      ANTIBODY_HOME = "$XDG_CACHE_HOME/antibody";
    };

    systemPackages = with pkgs; [
      zsh
      antibody
      nix-zsh-completions
      fasd
      exa
      fd
      tmux
      htop
      tree
    ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableGlobalCompInit = false; # I'll do it myself
    promptInit = "";
  };

  home-manager.users.emiller.xdg.configFile = {
    # link recursively so other modules can link files in this folder,
    # particularly in zsh/rc.d/*.zsh
    "zsh" = {
      source = <config/zsh>;
      recursive = true;
    };
  };
}
