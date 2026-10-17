{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.rex;
in
{
  options.modules.shell.rex.enable = mkBoolOpt false;

  config = mkIf cfg.enable {
    # The macOS beta app is installed separately. Nix owns only its config.
    home.configFile."rex/init.lua".source = "${config.dotfiles.configDir}/rex/init.lua";
    modules.agents.mcp.servers.superlogical.enable = mkDefault true;
  };
}
