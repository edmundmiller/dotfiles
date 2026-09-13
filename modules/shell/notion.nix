{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.notion;
in
{
  options.modules.shell.notion.enable = mkBoolOpt false;

  config = mkIf cfg.enable {
    # Authenticate interactively with `ntn login`; credentials stay in the keychain.
    home-manager.users.${config.user.name}.home.packages = [ pkgs.my.ntn ];
  };
}
