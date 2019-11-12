{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ R ];

  home-manager.users.emiller.xdg.configFile = {
    # "zsh/rc.d/aliases.R.zsh".source = <config/R/aliases.zsh>;
    # "zsh/rc.d/env.R.zsh".source = <config/R/env.zsh>;
  };
}
