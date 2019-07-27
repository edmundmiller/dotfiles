{ config, lib, pkgs, ... }:

{
    virtualisation.virtualbox.host.enable = true;

    users.groups.vboxusers.members = [ "emiller" ];
}
