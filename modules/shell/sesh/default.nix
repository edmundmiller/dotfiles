{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.sesh;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.sesh = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # sesh — tmux split with AI tool + lazygit
    # Shell function lives in config/sesh/aliases.zsh (auto-sourced by zsh module)
    # Requires: tmux (from tmux module), lazygit (from zsh module)

    home.configFile = {
      "sesh/lazygit-tml.yml".source = "${configDir}/sesh/lazygit-tml.yml";
    };
  };
}
