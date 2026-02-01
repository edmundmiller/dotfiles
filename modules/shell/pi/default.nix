# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Symlinks shared skills from config/agents/skills/
# - Generates AGENTS.md from config/agents/rules/
#
# Note: The shift+enter keybinding conflicts with OpenCode's binding.
# See config/ghostty/pi-keybindings.conf for details.
{
  config,
  lib,
  pkgs,
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
  piSettingsSource = "${configDir}/pi/settings.json";
  settingsJsonStripped =
    pkgs.runCommand "pi-settings-json"
      {
        src = piSettingsSource;
      }
      ''
        ${pkgs.gnused}/bin/sed '/^[[:space:]]*\/\//d' $src > $out
      '';
in
{
  options.modules.shell.pi = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # When Ghostty is enabled, add pi-specific keybindings
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable [
      "${configDir}/ghostty/pi-keybindings.conf"
    ];

    # Pi configuration via home-manager
    # - Skills are shared across all agents (Claude, OpenCode, Pi)
    # - AGENTS.md is built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name}.home.file = {
      ".pi/agent/skills".source = "${configDir}/agents/skills";
      ".pi/agent/AGENTS.md".text = concatenatedRules;
      ".pi/agent/settings.json".source = settingsJsonStripped;
    };
  };
}
