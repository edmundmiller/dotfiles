{ config, lib, pkgs, ... }:

{
  imports = [ ./polybar.nix ./dunst.nix ];

  services.xserver.windowManager.bspwm = { enable = true; };

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

    services.screen-locker = {
      enable = true;
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
