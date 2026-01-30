# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Symlinks shared skills from config/agents/skills/
#
# Note: The shift+enter keybinding conflicts with OpenCode's binding.
# See config/ghostty/pi-keybindings.conf for details.
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

    # Symlink shared skills to Pi's skills directory
    # Skills are shared across all agents (Claude, OpenCode, Pi)
    home-manager.users.${config.user.name}.home.file = {
      ".pi/agent/skills".source = "${configDir}/agents/skills";
    };
  };
}
