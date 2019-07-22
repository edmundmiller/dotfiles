{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ docker docker-compose ];

  virtualisation = {
    docker.enable = true;
    docker.autoPrune.enable = true;
    virtualbox.host.enable = true;
  };

  users = {
    users.emiller.extraGroups = [ "docker" ];
    groups.vboxusers.members = [ "emiller" ];
  };
}
