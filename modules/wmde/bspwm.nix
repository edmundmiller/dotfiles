{ config, lib, pkgs, ... }:

{
  imports =
  [ ./xserver.nix ./gtk.nix ./polybar.nix ./dunst.nix ./lockscreen.nix ];

  services.xserver.windowManager.bspwm = { enable = true; };
  environment.systemPackages = with pkgs; [ feh ];

  home-manager.users.emiller = {
    programs.rofi = {
      enable = true;
      extraConfig = ''
        rofi.modi: window,run,ssh,combi
        rofi.ssh-client: mosh
        rofi.ssh-command: {terminal} -e "{ssh-client} {host}"
        rofi.combi-modi: window,drun,ssh
        rofi.font: Iosevka 18
      '';
      terminal = "termite";
      theme = "Arc-Dark";
    };

    services.redshift = {
      enable = true;
      latitude = "32.78306";
      longitude = "-96.80667";
    };
    services.gnome-keyring = {
      enable = true;
      components = [ "secrets" ];
    };

    xdg.configFile = {
      "bspwm/bspwmrc".source = <config/bspwm/bspwmrc>;
      "sxhkd/sxhkdrc".source = <config/bspwm/sxhkdrc>;
    };
  };
}
