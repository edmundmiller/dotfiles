{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.ai;
in
{
  options.modules.shell.ai = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable { user.packages = [ pkgs.unstable.llm ]; };
}
