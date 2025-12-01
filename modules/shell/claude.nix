{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.claude;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.claude = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # Add claude-related packages if any
    ];

    home.file = {
      ".claude/settings.json".source = "${configDir}/claude/settings.json";
      # Note: settings.local.json, slash_commands, and commands are not tracked in git
      # and therefore not available in the nix store. Manage these locally if needed.
      ".claude/agents".source = "${configDir}/claude/agents";
      ".claude/config".source = "${configDir}/claude/config";
    };

    # Source Claude aliases in zsh
    modules.shell.zsh.rcFiles = [ "${configDir}/claude/aliases.zsh" ];
  };
}