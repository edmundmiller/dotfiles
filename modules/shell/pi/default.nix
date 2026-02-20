# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Symlinks shared skills from config/agents/skills/
# - Auto-discovers prompt templates from config/pi/prompts/
# - Auto-discovers local skills from config/pi/skills/
# - Auto-discovers subagent definitions from config/pi/agents/
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

  # Dynamically discover prompt templates from config/pi/prompts/
  promptsDir = "${configDir}/pi/prompts";
  promptFiles =
    if builtins.pathExists promptsDir then
      builtins.filter (f: lib.hasSuffix ".md" f) (builtins.attrNames (builtins.readDir promptsDir))
    else
      [ ];
  promptLinks = lib.listToAttrs (
    map (f: {
      name = ".pi/agent/prompts/${f}";
      value.source = "${promptsDir}/${f}";
    }) promptFiles
  );

  # Dynamically discover local skills from config/pi/skills/
  # Each subdirectory should contain a SKILL.md
  skillsDir = "${configDir}/pi/skills";
  skillDirs =
    if builtins.pathExists skillsDir then
      builtins.filter (d: builtins.pathExists "${skillsDir}/${d}/SKILL.md") (
        builtins.attrNames (builtins.readDir skillsDir)
      )
    else
      [ ];
  skillLinks = lib.listToAttrs (
    map (d: {
      name = ".pi/agent/skills/${d}/SKILL.md";
      value.source = "${skillsDir}/${d}/SKILL.md";
    }) skillDirs
  );

  # Dynamically discover subagent definitions from config/pi/agents/
  # Supports both .md (agents) and .chain.md (chains) for pi-subagents
  agentsDir = "${configDir}/pi/agents";
  agentFiles =
    if builtins.pathExists agentsDir then
      builtins.filter (f: lib.hasSuffix ".md" f) (builtins.attrNames (builtins.readDir agentsDir))
    else
      [ ];
  agentLinks = lib.listToAttrs (
    map (f: {
      name = ".pi/agent/agents/${f}";
      value.source = "${agentsDir}/${f}";
    }) agentFiles
  );

  # Convert JSONC to valid JSON:
  # 1. Strip full-line // comments
  # 2. Strip inline // comments (after JSON values, not inside strings)
  # 3. Remove trailing commas before } or ] (invalid in JSON)
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
  # Strip inline comments: split on " //" and keep only the first part
  # This handles patterns like: "value", // comment
  # Safe because JSON string values containing " //" would be unusual
  stripInlineComment =
    line:
    let
      parts = lib.splitString " //" line;
    in
    if builtins.length parts > 1 then builtins.head parts else line;
  piSettingsFiltered = map stripInlineComment (
    builtins.filter (line: !isCommentLine line) piSettingsLines
  );
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

  # Validate at Nix eval time — fails the build if JSONC stripping is broken
  piSettingsValidated =
    let
      parsed = builtins.tryEval (builtins.fromJSON piSettingsStripped);
    in
    if parsed.success then
      piSettingsStripped
    else
      builtins.throw "pi settings.jsonc produced invalid JSON after stripping comments/trailing commas. Run: nix eval --expr 'builtins.fromJSON (builtins.readFile ./result-settings.json)' to debug.";
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
    # pi-notify sound after system notification
    env.PI_NOTIFY_SOUND_CMD = "afplay /System/Library/Sounds/Hero.aiff";
    # pi-github-tools PAT (from gh CLI)
    env.GITHUB_PAT = "$(gh auth token 2>/dev/null)";
    # pi-tasks backend
    env.PI_TASKS_BACKEND = "beads";

    # Pi configuration via home-manager
    # - Skills are shared across all agents (Claude, OpenCode, Pi)
    # - AGENTS.md is built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.file =
          promptLinks
          // skillLinks
          // agentLinks
          // {
            ".pi/agent/AGENTS.md".text = concatenatedRules;
            ".pi/agent/settings.json".text = piSettingsValidated;
            ".pi/agent/extensions/enforce-commit-signing.ts".source =
              "${configDir}/pi/extensions/enforce-commit-signing.ts";
            ".pi/agent/extensions/enforce-hooks.ts".source = "${configDir}/pi/extensions/enforce-hooks.ts";
            ".pi/agent/extensions/gitbutler-guard.ts".source = "${configDir}/pi/extensions/gitbutler-guard.ts";
            ".pi/agent/extensions/gitbutler-guard-logic.ts".source =
              "${configDir}/pi/extensions/gitbutler-guard-logic.ts";
            ".pi/agent/extensions/direnv.ts".source = "${configDir}/pi/extensions/direnv.ts";
            ".pi/agent/extensions/process-info.ts".source = "${configDir}/pi/extensions/process-info.ts";
            ".pi/agent/extensions/critique.ts".source = "${configDir}/pi/extensions/critique.ts";
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

            # GitButler `but` skill pinned via skills-catalog flake (gitbutlerapp/gitbutler repo)
            # so we don't mutate skills dirs at activation-time.

            # Install deps for local pi packages (use $HOME path, not nix store)
            for pkg_dir in "$HOME/.config/dotfiles/packages/pi-context-repo" "$HOME/.config/dotfiles/packages/pi-dcp" "$HOME/.config/dotfiles/packages/pi-scurl"; do
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
