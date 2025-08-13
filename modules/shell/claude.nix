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
      ".claude/settings.local.json".source = "${configDir}/claude/.claude/settings.local.json";
      ".claude/slash_commands".source = "${configDir}/claude/slash_commands";
      ".claude/agents".source = "${configDir}/claude/agents";
      ".claude/commands".source = "${configDir}/claude/commands";
      ".claude/config".source = "${configDir}/claude/config";
    };
  };
}