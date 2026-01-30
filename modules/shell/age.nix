{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.age;
in
{
  options.modules.shell.age = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable { user.packages = [ pkgs.rage ]; };
}
