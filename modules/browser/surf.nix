# modules/browser/firefox.nix --- https://www.mozilla.org/en-US/firefox

{ config, lib, pkgs, fetchurl, ... }:
let
  scrollback = fetchurl {
    url = "https://st.suckless.org/patches/scrollback/st-scrollback-0.8.diff";
    sha1 = "623f474b62fb08e0b470673bf8ea947747e1af8b";
  };
  scrollbackMouse = fetchurl {
    url =
      "https://st.suckless.org/patches/scrollback/st-scrollback-mouse-0.8.diff";
    sha1 = "46e92d9d3f6fd1e4f08ed99bda16b232a1687407";
  };
  scrollbackMouseAltscreen = fetchurl {
    url =
      "https://st.suckless.org/patches/scrollback/st-scrollback-mouse-altscreen-0.8.diff";
    sha1 = "d3329413998c5f3feaa7764db36269bf7b3d1334";
  };
  alpha = fetchurl {
    url = "https://st.suckless.org/patches/alpha/st-alpha-0.8.1.diff";
    sha1 = "cc85d9b1f4efa27cb7f233125e68fbfd06b758fe";
  };
in {
  nixpkgs.config.packageOverrides = pkgs: {
    surf = pkgs.surf.override {
      patches = [
        ./dwm/dwm-st.patch
        ./dwm/dwm-6.0-font-size.diff
        ./dwm/dwm-6.0-cmd-for-modifier.diff
      ];
    };
  };
  my.packages = with pkgs; [
    (pkgs.writeScriptBin "tabbed-surf-bin" ''
      #!${stdenv.shell}
      ${tabbed}/bin/tabbed ${surf}/bin/surf -pe
    '')
    dmenu
    # (makeDesktopItem {
    #   name = "firefox-private";
    #   desktopName = "Firefox (Private)";
    #   genericName = "Open a private Firefox window";
    #   icon = "firefox";
    #   exec = "${firefox-bin}/bin/firefox --private-window";
    #   categories = "Network";
    # })
  ];
}
