{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./rofi.nix
  ];

  environment = {
    systemPackages = with pkgs; [
      lightdm
      bspwm
      dunst
      libnotify
      (polybar.override {
        pulseSupport = true;
        nlSupport = true;
      })

      xst # st + nice-to-have extensions
      (makeDesktopItem {
        name = "xst";
        desktopName = "Suckless Terminal";
        genericName = "Default terminal";
        icon = "utilities-terminal";
        exec = "${xst}/bin/xst";
        categories = "Development;System;Utility";
      })
    ];
  };

  fonts.fonts = [ pkgs.siji ];

  programs.zsh.interactiveShellInit = "export TERM=xterm-256color";

  services = {
    xserver = {
      desktopManager.xterm.enable = false;
      windowManager.bspwm.enable = true;
      displayManager.lightdm = {
        enable = true;
        greeters.mini = {
          enable = true;
          user = "emiller";
        };
      };
    };

    compton = {
      enable = true;
      backend = "glx";
      vSync = true;
    };

  };

  home-manager.users.emiller.xdg.configFile = {
    "sxhkd" = {
      source = <config/sxhkd>;
      recursive = true;
    };
    # link recursively so other modules can link files in their folders
    "bspwm" = {
      source = <config/bspwm>;
      recursive = true;
    };
  };
}
