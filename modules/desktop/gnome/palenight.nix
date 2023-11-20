{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix.image = ../../themes/functional/config/wallpaper.png;
  stylix.polarity = "dark";
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/material-palenight.yaml";
  stylix.fonts = {
    serif.package = pkgs.dejavu_fonts;
    serif.name = "DejaVu Serif";

    sansSerif.package = pkgs.fira;
    sansSerif.name = "Fira Sans";

    monospace.package = pkgs.jetbrains-mono;
    monospace.name = "JetBrains Mono";
  };
  stylix.targets.gnome.enable = true;
}
