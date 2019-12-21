{ config, lib, pkgs, ... }:

{
  imports = [ ./keybase.nix ./pia.nix ./transmission.nix ./syncthing.nix ];

  # services.autorandr = {
  #   enable = true;
  #   defaultTarget = "main";
  # };
  services = {
    printing.enable = true;
    gnome3.chrome-gnome-shell.enable = true;
    localtime.enable = true;
    dbus.packages = with pkgs; [ gnome3.dconf ];
  };
}
