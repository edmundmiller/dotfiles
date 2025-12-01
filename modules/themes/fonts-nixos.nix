# fonts-nixos.nix
# NixOS-specific font configuration for themes
# This file is filtered out on Darwin (see default.nix module loading)
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
  config = mkIf (!isDarwin && cfg.active != null) {
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ cfg.fonts.sans.name ];
      monospace = [ cfg.fonts.mono.name ];
    };
  };
}
