{ config, lib, pkgs, ... }:

{
  imports = [ ./keybase.nix ./pia.nix ./transmission.nix ./syncthing.nix ];

  # services.autorandr = {
  #   enable = true;
  #   defaultTarget = "main";
  # };
}
