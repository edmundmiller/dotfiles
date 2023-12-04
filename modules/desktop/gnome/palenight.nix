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
    serif.package = pkgs.ibm-plex;
    serif.name = "IBM Plex Serif";

    sansSerif.package = pkgs.ibm-plex;
    sansSerif.name = "IBM Plex Sans";

    monospace.package = pkgs.jetbrains-mono;
    monospace.name = "JetBrains Mono";
  };
  stylix.targets.gnome.enable = true;

  boot.plymouth.enable = true;
}
