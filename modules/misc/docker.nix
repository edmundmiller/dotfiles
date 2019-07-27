{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ docker docker-compose ];

  virtualisation = {
    docker.enable = true;
    docker.autoPrune.enable = true;
  };

  users.users.emiller.extraGroups = [ "docker" ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.docker.zsh".source = <config/docker/aliases.zsh>;
    "zsh/rc.d/env.docker.zsh".source = <config/docker/env.zsh>;
  };
}
