{ config, lib, pkgs, ... }:

{
  imports = [
    ./xserver.nix
    ./gtk.nix
    ./polybar.nix
    ./dunst.nix
    ./lockscreen.nix
    ./compton.nix
  ];

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
        rofi.font: Iosevka 21
      '';
      terminal = "termite";
      theme = "flat-orange";
    };

    services.redshift = {
      enable = true;
      latitude = "32.78306";
      longitude = "-96.80667";
    };

    xdg.configFile = {
      "bspwm/bspwmrc".source = <config/bspwm/bspwmrc>;
      "sxhkd/sxhkdrc".source = <config/bspwm/sxhkdrc>;
      "rofi" = {
        source = <config/rofi>;
        recursive = true;
      };
    };
  };
}
