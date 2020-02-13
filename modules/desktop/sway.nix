{ config, lib, pkgs, ... }:

{
  imports = [
    ./.

    ./apps/rofi.nix
    #
    ./apps/redshift.nix
    #
    ./apps/st.nix
  ];

  fonts.fonts = [ pkgs.siji ];

  programs.zsh.interactiveShellInit = "export TERM=xterm-256color";

  programs.sway = {
    enable = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      xwayland
      waybar
      make
      kanshi
    ];
  };

  services.redshift.package = pkgs.redshift-wlr;

  environment.systemPackages = with pkgs; [
  ];

  home-manager.users.emiller.xdg.configFile = {
    "sway" = {
      source = <config/sway>;
      recursive = true;
    };
  };

}
