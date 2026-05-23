{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents;
in
{
  options.modules.agents = {
    gnhf.enable = mkBoolOpt false;
  };

  config = mkIf cfg.gnhf.enable {
    user.packages = [ pkgs.llm-agents.gnhf ];
  };
}
