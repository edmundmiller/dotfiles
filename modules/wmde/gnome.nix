{ config, lib, pkgs, ... }:

{
  services = {
    gnome3.chrome-gnome-shell.enable = true;

    xserver = {
      enable = true;
      layout = "us";
      xkbOptions = "caps:escape";
      videoDrivers = [ "nvidiaBeta" ];
      libinput = {
        enable = true;
        disableWhileTyping = true;
        tapping = false;
      };

      displayManager = {
        gdm.enable = true;
        gdm.wayland = false;
      };
      desktopManager.gnome3.enable = true;
    };
  };

  home-manager.users.emiller = {
    gtk = {
      enable = true;
      theme = {
        package = pkgs.sierra-gtk-theme;
        name = "Sierra-compact-dark";
      };
      iconTheme = {
        package = pkgs.paper-icon-theme;
        name = "Paper-Mono-Dark";
      };
      # Give Termite some internal spacing.
      gtk3.extraCss = ".termite {padding: 20px;}";
    };
  };
}
