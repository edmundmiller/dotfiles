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
  stylix.fonts.monospace.package = pkgs.jetbrains-mono;
  stylix.fonts.monospace.name = "JetBrains Mono";
  stylix.targets.gnome.enable = true;
}
