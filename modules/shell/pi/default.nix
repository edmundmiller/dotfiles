# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Installs pi via npm (global package)
# - Configures Ghostty keybindings when Ghostty is enabled
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
    # Install pi coding agent via npm
    # TODO: Check if there's a nix package or homebrew formula available
    # For now, install via: npm install -g @mariozechner/pi-coding-agent
    # Or: bun add -g @mariozechner/pi-coding-agent

    # When Ghostty is enabled, add pi-specific keybindings
    modules.desktop.term.ghostty.extraConfigFiles = mkIf ghosttyCfg.enable [
      "pi-keybindings.conf"
    ];

    # Install pi keybindings config when ghostty is enabled
    home.configFile = mkIf ghosttyCfg.enable {
      "ghostty/pi-keybindings.conf".source = "${configDir}/ghostty/pi-keybindings.conf";
    };
  };
}
