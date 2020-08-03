{ config, lib, pkgs, ... }:

{
  imports = [
    ./calibre.nix
    ./docker.nix
    # ./gitea.nix
    # ./jellyfin.nix
    ./keybase.nix
    ./mpd.nix
    # ./nginx.nix
    ./pia.nix
    ./ssh.nix
    ./ssh-agent.nix
    ./syncthing.nix
    ./transmission.nix
  ];
}
