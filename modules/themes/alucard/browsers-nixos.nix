# browsers-nixos.nix - Browser customizations for alucard theme (NixOS only)
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
  config = mkIf (!isDarwin && cfg.active == "alucard") {
    modules.desktop.browsers = {
      firefox.userChrome = concatMapStringsSep "\n" readFile [ ./config/firefox/userChrome.css ];
    };
  };
}
