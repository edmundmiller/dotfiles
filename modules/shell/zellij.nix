{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.zellij;
in
{
  options.modules.shell.zellij = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name}.programs.zellij = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
