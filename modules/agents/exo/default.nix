{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.my) mkBoolOpt;
  cfg = config.modules.agents.exo;
in
{
  options.modules.agents.exo = {
    enable = mkBoolOpt false;
    package = mkOption {
      type = types.package;
      default = pkgs.my.exo;
      description = "Pinned Exo CLI package.";
    };
  };

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];
  };
}
