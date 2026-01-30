# modules/desktop/term/warp.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.warp;
in
{
  options.modules.desktop.term.warp = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable { user.packages = with pkgs; [ unstable.warp-terminal ]; };
}
