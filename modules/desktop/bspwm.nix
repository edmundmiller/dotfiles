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
    bspwm
    dunst
    libnotify
    (polybar.override {
      mpdSupport = true;
      pulseSupport = true;
      nlSupport = true;
    })
  ];

  fonts.fonts = [ pkgs.siji ];

  programs.zsh.interactiveShellInit = "export TERM=xterm-256color";
  programs.slock.enable = true;

  services = {
    xserver = {
      desktopManager.xterm.enable = false;
      windowManager.bspwm.enable = true;
      windowManager.default = "bspwm";
      displayManager.lightdm = {
        enable = true;
        greeters.mini = {
          enable = true;
          user = config.my.username;
        };
      };
      xautolock = {
        enable = true;
        enableNotifier = true;
        notifier = ''
          ${pkgs.libnotify}/bin/notify-send "Locking in 10 seconds"
        '';
        killer = "${pkgs.systemd}/bin/systemctl suspend";
        locker = "${pkgs.slock}/bin/slock";
      };
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
