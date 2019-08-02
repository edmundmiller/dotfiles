{ config, lib, pkgs, ... }:

{
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
    qt = {
      enable = false;
      useGtkTheme = true;
    };
  };
}
