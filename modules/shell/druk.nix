{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.druk;
in
{
  options.modules.shell.druk.enable = mkBoolOpt false;

  config = mkIf cfg.enable {
    # Pin upgrades through the Nix package; `druk update` is for other install methods.
    user.packages = [ pkgs.my.druk ];
  };
}
