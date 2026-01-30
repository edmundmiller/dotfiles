{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.my) mkBoolOpt;
  cfg = config.modules.shell.opencode;
  ghosttyCfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.opencode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # When Ghostty is enabled, add OpenCode-specific keybindings
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable [
      "${configDir}/ghostty/opencode-keybindings.conf"
    ];
    # OpenCode is installed via homebrew (not nix) for better macOS integration
    # See: brew install opencode

    home-manager.users.${config.user.name} =
      { config, lib, ... }:
      let
        opencodeConfigDir = "${config.home.homeDirectory}/.config/opencode";
      in
      {
        # Symlink config files to ~/.config/opencode/
        xdg.configFile = {
          "opencode/opencode.jsonc".source = "${configDir}/opencode/opencode.jsonc";
          "opencode/smart-title.jsonc".source = "${configDir}/opencode/smart-title.jsonc";
          "opencode/dcp.jsonc".source = "${configDir}/opencode/dcp.jsonc";

          # Skills and modes shared across all agents (Claude, OpenCode, Pi)
          # Single source of truth in config/agents/
          "opencode/rules" = {
            source = "${configDir}/agents/rules";
            recursive = true;
          };
          "opencode/agent" = {
            source = "${configDir}/agents/modes";
            recursive = true;
          };
          "opencode/skill" = {
            source = "${configDir}/agents/skills";
            recursive = true;
          };
          "opencode/command" = {
            source = "${configDir}/opencode/command";
            recursive = true;
          };
          # Note: tool/ is copied via activation script (not symlinked)
          # because TypeScript tools need to resolve node_modules from ~/.config/opencode/

          # Nix-built plugin: opencode-tmux-namer
          # Built at nix-build time, symlinked here
          "opencode/plugin/opencode-tmux-namer" = {
            source = pkgs.my.opencode-tmux-namer;
          };
        };

        home.activation.opencode-setup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Ensure plugin directory exists (user-managed plugins go here too)
          ${pkgs.coreutils}/bin/mkdir -p "${opencodeConfigDir}/plugin"
          ${pkgs.coreutils}/bin/mkdir -p "${opencodeConfigDir}/tool"

          # Copy package.json (can't symlink - bun install modifies lockfile location)
          ${pkgs.coreutils}/bin/cp -f "${configDir}/opencode/package.json" "${opencodeConfigDir}/package.json"

          # Copy tool/ directory (can't symlink - TypeScript needs to resolve node_modules)
          ${pkgs.rsync}/bin/rsync -a --delete "${configDir}/opencode/tool/" "${opencodeConfigDir}/tool/"

          # Install dependencies if bun is available
          if command -v bun &> /dev/null; then
            cd "${opencodeConfigDir}"

            # Only run if dependencies likely changed
            if [ ! -d node_modules ] || [ ! -f bun.lockb ]; then
              echo "Running bun install for OpenCode dependencies..."
              bun install --silent || echo "Warning: bun install failed; OpenCode plugins may be incomplete."
            fi
          fi
        '';
      };
  };
}
