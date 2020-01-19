# modules/browser/firefox.nix --- https://www.mozilla.org/en-US/firefox

{ config, lib, pkgs, ... }: {
  my.packages = with pkgs; [
    firefox-bin
    (pkgs.writeScriptBin "firefox-private" ''
      #!${stdenv.shell}
      ${firefox}/bin/firefox --private-window "$@"
    '')
    (makeDesktopItem {
      name = "firefox-private";
      desktopName = "Firefox (Private)";
      genericName = "Open a private Firefox window";
      icon = "firefox";
      exec = "${firefox-bin}/bin/firefox --private-window";
      categories = "Network";
    })
    tridactyl-native # FIXME still have to run in firefox
    libu2f-host # Yubikey
  ];

  my.env.BROWSER = "firefox";
  my.env.XDG_DESKTOP_DIR = "$HOME"; # prevent firefox creating ~/Desktop
  my.home.xdg = {
    configFile."tridactyl/tridactylrc".source = <config/tridactyl/tridactylrc>;
  };
}
