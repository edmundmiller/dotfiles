{ config, lib, ... }:
with lib;
with lib.my;
let
  cfg = config.modules.agents.hermes;
in
{
  options.modules.agents.hermes = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = false;
        message = ''
          modules.agents.hermes has been retired.
          Use modules.agents.hermes-desktop for interactive desktop Hermes.
          NUC gateway profiles belong under services.hermes / services.hermes-agent.
        '';
      }
    ];
  };
}
