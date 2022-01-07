# modules/browser/nyxt.nix --- https://github.com/nyxt/nyxt

{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.browsers.nyxt;
in
{
  options.modules.desktop.browsers.nyxt = with types; {
    enable = mkBoolOpt false;
    userStyles = mkOpt lines "";
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs;
      [
        unstable.nyxt
        # (makeDesktopItem {
        #   name = "nyxt-private";
        #   desktopName = "Nyxt (Private)";
        #   genericName = "Open a private Nyxt window";
        #   icon = "nyxt";
        #   categories = "Network";
        # })
      ];

    # home = {
    #   configFile."nyxt" = {
    #     source = "${configDir}/nyxt";
    #     recursive = true;
    #   };
    #   # dataFile."nyxt/userstyles.css".text = cfg.userStyles;
    # };
  };
}
