{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.agents.browse;
in
{
  options.modules.agents.browse.enable = lib.my.mkBoolOpt false;

  config = lib.mkIf cfg.enable {
    user.packages = [ pkgs.my.opencode-browse ];
  };
}
