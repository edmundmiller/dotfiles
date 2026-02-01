# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Symlinks shared skills from config/agents/skills/
# - Generates AGENTS.md from config/agents/rules/
# - Strips // comments from settings.json (pi only supports standard JSON)
#
# Note: The shift+enter keybinding conflicts with OpenCode's binding.
# See config/ghostty/pi-keybindings.conf for details.
#
# Note: settings.json is nix-managed (read-only). Pi will show a warning
# "Could not save settings file" when it tries to persist runtime state
# (e.g., last selected model). This is expected and harmless.
{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.pi;
  ghosttyCfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;

  # Dynamically concatenate all rule files from config/agents/rules/
  # Same logic as Claude module for consistency
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f) (builtins.attrNames (builtins.readDir rulesDir))
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;

  # Strip // comments from JSON (pi doesn't support JSONC)
  # Only removes lines that start with // (preserves URLs like https://)
  piSettingsRaw = builtins.readFile "${configDir}/pi/settings.json";
  piSettingsLines = lib.splitString "\n" piSettingsRaw;
  isCommentLine =
    line:
    lib.hasPrefix "//" (
      lib.trimWith {
        start = true;
        end = false;
      } line
    );
  piSettingsFiltered = builtins.filter (line: !isCommentLine line) piSettingsLines;
  piSettingsStripped = lib.concatStringsSep "\n" piSettingsFiltered;
in
{
  options.modules.shell.pi = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # When Ghostty is enabled, add pi-specific keybindings
    # mkAfter ensures pi's shift+enter binding wins over opencode's
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable (mkAfter [
      "${configDir}/ghostty/pi-keybindings.conf"
    ]);

    # Pi configuration via home-manager
    # - Skills are shared across all agents (Claude, OpenCode, Pi)
    # - AGENTS.md is built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name}.home.file = {
      ".pi/agent/skills".source = "${configDir}/agents/skills";
      ".pi/agent/AGENTS.md".text = concatenatedRules;
      ".pi/agent/settings.json".text = piSettingsStripped;
    };
  };
}
