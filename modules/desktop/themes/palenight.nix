{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.themes.palenight;
in
{
  options.modules.desktop.themes.palenight = {
    enable = mkBoolOpt false;
  };
  imports = [ inputs.stylix.nixosModules.stylix ];

  config = mkIf cfg.enable {
    stylix.enable = true;
    stylix.image = ../../themes/functional/config/wallpaper.png;
    stylix.polarity = "dark";
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/material-palenight.yaml";
    stylix.autoEnable = true;
    stylix.fonts = {
      serif.package = pkgs.dejavu_fonts;
      serif.name = "DejaVu Serif";

      sansSerif.package = pkgs.fira;
      sansSerif.name = "Fira Sans";

      monospace.package = pkgs.jetbrains-mono;
      monospace.name = "JetBrains Mono";
      # TODO https://github.com/danth/stylix/issues/166
      # stylix.fonts.monospace.package = pkgs.nerdfonts.override {fonts = ["FiraCode"];};

      sizes = {
        applications = 14;
        desktop = 13;
        popups = 12;
        terminal = 14;
      };
    };
    stylix.cursor.package = pkgs.catppuccin-cursors.frappeDark;
    stylix.cursor.name = "catppuccin-frappe-dark-cursors";
    stylix.cursor.size = 24;

    stylix.opacity.terminal = 0.97;

    boot.plymouth.enable = true;
  };
}
