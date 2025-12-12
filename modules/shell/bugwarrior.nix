# modules/shell/bugwarrior.nix
# Bugwarrior configuration for syncing issues from GitHub, Linear, etc. to Taskwarrior
{
  config,
  options,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.bugwarrior;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.bugwarrior = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Bugwarrior requires taskwarrior
    modules.shell.taskwarrior.enable = true;

    # Zsh aliases for bugwarrior commands
    modules.shell.zsh.rcFiles = [ "${configDir}/bugwarrior/aliases.zsh" ];

    # Symlink bugwarrior.toml to ~/.config/bugwarrior/
    home-manager.users.${config.user.name} = {
      xdg.configFile."bugwarrior/bugwarrior.toml".source =
        "${configDir}/bugwarrior/bugwarrior.toml";
    };
  };
}
