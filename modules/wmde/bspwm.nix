{ config, lib, pkgs, ... }:

{
  imports = [
    ./features/xserver.nix
    ./features/gtk.nix
    ./features/polybar.nix
    ./features/dunst.nix
    ./features/lockscreen.nix
    ./features/compton.nix
    ./features/lightdm.nix
  ];

  services.xserver.windowManager.bspwm = { enable = true; };
  services.xserver.windowManager.default = "bspwm";

  environment.systemPackages = with pkgs; [ feh ];

  home-manager.users.emiller = {
    programs.rofi = {
      enable = true;
      extraConfig = ''
        rofi.modi: window,run,ssh,combi
        rofi.ssh-client: ssh
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
      temperature = { night = 2500; };
    };

    xdg.configFile = {
      "bspwm/bspwmrc".source = <config/bspwm/bspwmrc>;
      "sxhkd/sxhkdrc".source = <config/sxhkd/sxhkdrc>;
      "rofi" = {
        source = <config/rofi>;
        recursive = true;
      };
    };
  };
}
