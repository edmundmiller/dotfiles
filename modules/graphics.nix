# modules/graphics.nix
#
# I never developed an adobe addition and ignorance is bliss. I grew up using
# gimp, and aseprite is slick.

{ config, lib, pkgs, ... }: {
  my = {
    packages = with pkgs; [
      font-manager # so many damned fonts...

      imagemagick # for image manipulation from the shell
      aseprite-unfree # pixel art
      inkscape # illustrator & indesign
      krita # replaces photoshop
      gimp # replaces photoshop
      gimpPlugins.resynthesizer2 # content-aware scaling in gimp
    ];

    home.xdg.configFile = {
      "GIMP/2.10" = {
        source = <config/gimp>;
        recursive = true;
      };
    };
  };
}
