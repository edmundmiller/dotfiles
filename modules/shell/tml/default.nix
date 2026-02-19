{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.tml;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.tml = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # tml — tmux dev layout: AI tool + lazygit + shell
    # Shell function in config/tml/aliases.zsh (auto-sourced by zsh module)
    # Requires: tmux (from tmux module), lazygit (from zsh module)

    home.configFile = {
      "lazygit/tml.yml".source = "${configDir}/lazygit/tml.yml";
    };
  };
}
