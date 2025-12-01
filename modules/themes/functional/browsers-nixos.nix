# browsers-nixos.nix - Browser customizations for functional theme (NixOS only)
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
let
  cfg = config.modules.theme;
in
{
  config = mkIf (!isDarwin && cfg.active == "functional") {
    modules.desktop.browsers = {
      firefox.userChrome = concatMapStringsSep "\n" readFile [ ./config/firefox/userChrome.css ];
    };
  };
}
