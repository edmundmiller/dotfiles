{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.moshi;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.moshi = {
    enable = mkBoolOpt false;
    tmuxHelper.enable = mkBoolOpt config.modules.shell.tmux.enable;
  };

  config = mkIf cfg.enable {
    modules.shell.zsh.rcFiles = mkIf cfg.tmuxHelper.enable [ "${configDir}/moshi/aliases.zsh" ];
  };
}
