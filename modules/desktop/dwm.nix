{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./apps/rofi.nix
    ./apps/thunar.nix
    #
    ./apps/redshift.nix
    #
    ./apps/st.nix
  ];

  environment.systemPackages = with pkgs; [
    lightdm
    dunst
    libnotify
    # (polybar.override {
    #   mpdSupport = true;
    #   pulseSupport = true;
    #   nlSupport = true;
    # })
  ];

  nixpkgs.overlays = [
    (self: super: {
      dwm = super.dwm.overrideAttrs (oa: {
        patches = oa.patches ++ [
          (builtins.fetchurl
            "https://dwm.suckless.org/patches/uselessgap/dwm-uselessgap-6.2.diff")
        ];
      });
    })
  ];

  fonts.fonts = [ pkgs.siji ];

  programs.zsh.interactiveShellInit = "export TERM=xterm-256color";
  programs.slock.enable = true;

  services = {
    xserver = {
      desktopManager.xterm.enable = false;
      windowManager.dwm.enable = true;
      windowManager.default = "dwm";
      displayManager.lightdm = {
        enable = true;
        greeters.mini = {
          enable = true;
          user = config.my.username;
        };
      };
    };
    dwm-status = {
      enable = true;
      order = [ "audio" "backlight" "battery" "cpu_load" "network" "time" ];
    };
    compton.enable = true;
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
