{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ openjdk11 gradle ];

  home-manager.users.emiller.xdg.configFile = {
    # "zsh/rc.d/aliases.java.zsh".source = <config/java/aliases.zsh>;
    # "zsh/rc.d/env.java.zsh".source = <config/java/env.zsh>;
  };
}
