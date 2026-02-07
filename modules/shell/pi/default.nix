# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Symlinks shared skills from config/agents/skills/
# - Generates AGENTS.md from config/agents/rules/
# - Strips // comments from settings.jsonc (pi only supports standard JSON)
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

  # Convert JSONC to valid JSON:
  # 1. Strip // comment lines (preserves URLs like https://)
  # 2. Remove trailing commas before } or ] (invalid in JSON)
  piSettingsRaw = builtins.readFile "${configDir}/pi/settings.jsonc";
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
  # Remove trailing commas by stripping commas from lines where the next
  # non-empty line starts with ] or }
  removeTrailingCommas =
    lines:
    let
      indexed = lib.imap0 (i: line: { inherit i line; }) lines;
      # Find next non-empty line after index i
      nextNonEmpty =
        i:
        let
          rest = lib.drop (i + 1) lines;
          nonEmpty = builtins.filter (l: builtins.match "^[[:space:]]*$" l == null) rest;
        in
        if nonEmpty == [ ] then "" else builtins.head nonEmpty;
      stripTrailingComma =
        { i, line }:
        let
          next = nextNonEmpty i;
          trimmedNext = lib.trimWith {
            start = true;
            end = false;
          } next;
          nextStartsClosing = lib.hasPrefix "]" trimmedNext || lib.hasPrefix "}" trimmedNext;
          trimmedLine = lib.removeSuffix " " (lib.removeSuffix "\t" line);
          hasTrailingComma = lib.hasSuffix "," trimmedLine;
        in
        if hasTrailingComma && nextStartsClosing then lib.removeSuffix "," trimmedLine else line;
    in
    map stripTrailingComma indexed;
  piSettingsClean = removeTrailingCommas piSettingsFiltered;
  piSettingsStripped = lib.concatStringsSep "\n" piSettingsClean;
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

    user.packages = [ pkgs.bun ];
    env.BUN_INSTALL = mkDefault "$HOME/.bun";
    env.PATH = mkAfter [ "$HOME/.bun/bin" ];

    # Pi configuration via home-manager
    # - Skills are shared across all agents (Claude, OpenCode, Pi)
    # - AGENTS.md is built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.file = {
          ".pi/agent/skills".source = "${configDir}/agents/skills";
          ".pi/agent/AGENTS.md".text = concatenatedRules;
          ".pi/agent/settings.json".text = piSettingsStripped;

        };

        home.activation.pi-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          bun_bin="${pkgs.bun}/bin/bun"
          if [ -x "$bun_bin" ]; then
            bun_install_dir="''${BUN_INSTALL:-}"
            if [ -z "$bun_install_dir" ]; then
              bun_install_dir="$HOME/.bun"
            fi
            if [ ! -x "$bun_install_dir/bin/pi" ]; then
              echo "Installing pi coding agent..."
              "$bun_bin" install -g @mariozechner/pi-coding-agent \
                || echo "Warning: bun install failed; pi may be unavailable."
            fi
            # Suppress bun "No license field" warning on ~/package.json
            if [ -f "$HOME/package.json" ] && ! grep -q '"license"' "$HOME/package.json"; then
              ${pkgs.jq}/bin/jq '. + {license: "UNLICENSED"}' "$HOME/package.json" > "$HOME/package.json.tmp" \
                && mv "$HOME/package.json.tmp" "$HOME/package.json"
            fi

            # Install deps for local pi packages (use $HOME path, not nix store)
            for pkg_dir in "$HOME/.config/dotfiles/packages/pi-dcp"; do
              if [ -d "$pkg_dir" ] && [ ! -d "$pkg_dir/node_modules" ]; then
                echo "Installing deps for $(basename "$pkg_dir")..."
                # Drop to user if running as root (sudo darwin-rebuild)
                if [ "$(id -u)" = "0" ]; then
                  /usr/bin/su ${config.user.name} -c "cd '$pkg_dir' && '$bun_bin' install" \
                    || echo "Warning: $(basename "$pkg_dir") bun install failed."
                else
                  (cd "$pkg_dir" && "$bun_bin" install) \
                    || echo "Warning: $(basename "$pkg_dir") bun install failed."
                fi
              fi
            done
          fi
        '';
      };
  };
}
