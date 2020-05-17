# modules/browser/next.nix --- https://github.com/atlas-engineer/next
#

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.desktop.browsers.next = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.desktop.browsers.next.enable {
    my.packages = with pkgs; [
      unstable.next
      (makeDesktopItem {
        name = "Next";
        desktopName = "Next";
        genericName = "Next Browser";
        icon = "next";
        exec = "${unstable.next}/bin/next";
        categories = "Network";
      })
    ];
    my.home.xdg.configFile."next" = {
      source = <config/next>;
      recursive = true;
    };
  };
}
