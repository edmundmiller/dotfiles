{ config, lib, pkgs, ... }:

let
  url = "https://github.com/colemickens/nixpkgs-wayland/archive/master.tar.gz";
  waylandOverlay = (import (builtins.fetchTarball url));
in {
  imports = [
    ./.

    ./apps/rofi.nix
    #
    ./apps/redshift.nix
    #
    ./apps/st.nix
  ];

  # nixpkgs.overlays = [ waylandOverlay ];

  fonts.fonts = [ pkgs.siji ];

  programs.zsh.interactiveShellInit = "export TERM=xterm-256color";

  programs.sway = {
    enable = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      xwayland
      waybar
      mako
      kanshi
      i3status-rust
    ];
  };

  services.redshift.package = pkgs.unstable.redshift-wlr;

  home-manager.users.emiller.xdg.configFile = {
    "sway" = {
      source = <config/sway>;
      recursive = true;
    };
  };
}
