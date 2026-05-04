{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.acpx;
in
{
  options.modules.shell.acpx = {
    enable = mkBoolOpt false;
    package = mkOpt (nullOr types.package) (pkgs.my.acpx or null);
    command = mkOpt types.str "acpx";
  };

  config = mkIf cfg.enable {
    user.packages = optional (cfg.package != null) cfg.package;
  };
}
