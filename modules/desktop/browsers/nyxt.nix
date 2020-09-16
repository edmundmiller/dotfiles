# modules/browser/nyxt.nix --- https://github.com/nyxt/nyxt
#
# Nyxt is cute because it's not enough of a browser to be handsome.
# Still, we can all tell he'll grow up to be one hell of a lady-killer.

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.desktop.browsers.nyxt = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.desktop.browsers.nyxt.enable {
    my.packages = with pkgs;
      [
        (makeDesktopItem {
          name = "nyxt";
          desktopName = "Nyxt";
          genericName = "Open a Nyxt window";
          icon = "nyxt";
          exec = "nyxt";
          categories = "Network";
        })
      ];
    my.env.GDK_SCALE = "2";
    my.env.GDK_DPI_SCALE = "0.5";

    # my.home.xdg.configFile."nyxt" = {
    #   source = <config/nyxt>;
    #   recursive = true;
    # };
  };
}
