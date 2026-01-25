# modules/shell/workmux/default.nix
#
# Workmux - Tmux-native git worktree manager for parallel AI agent workflows
# https://workmux.raine.dev
{
  options,
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.workmux;
in
{
  options.modules.shell.workmux = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Require tmux module
    assertions = [
      {
        assertion = config.modules.shell.tmux.enable;
        message = "workmux requires tmux module to be enabled";
      }
    ];

    # Install workmux from flake
    user.packages = [
      inputs.workmux.packages.${pkgs.system}.default
    ];

    # Symlink config file
    home.configFile."workmux/config.yaml".source = "${configDir}/workmux/config.yaml";

    # Shell aliases
    modules.shell.zsh.rcFiles = [ "${configDir}/workmux/aliases.zsh" ];
  };
}
