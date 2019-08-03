{ config, lib, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ qt5.qtbase libsForQt5.vlc ];
  programs.qt5ct.enable = true;
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
