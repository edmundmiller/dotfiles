# modules/browser/zen.nix --- https://www.zen-browser.app/
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.browsers.zen;
in
{
  options.modules.desktop.browsers.zen = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ inputs.zen-browser.packages."${system}".default ];
  };

  # tridactyl
  home.configFile = {
    "tridactyl/tridactylrc".source = "${configDir}/tridactyl/tridactylrc";
  };
}
