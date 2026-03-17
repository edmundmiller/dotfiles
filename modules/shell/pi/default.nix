# modules/shell/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Auto-discovers prompt templates from config/pi/prompts/
# - Auto-discovers pi-specific skills from config/pi/skills/
# - Auto-discovers cross-agent shared skills from config/agents/skills/
# Note: Pi also natively discovers ~/.agents/skills/ (for manually installed global skills)
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

  # Pre-built node_modules for pi-packages with npm dependencies
  piPkgDeps = import ./lib/_pi-package-deps.nix {
    inherit pkgs;
    piPkgsDir = ../../../pi-packages;
  };

  # Dynamically concatenate all rule files from config/agents/rules/
  # Same logic as Claude module for consistency
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f && f != "AGENTS.md") (
      builtins.attrNames (builtins.readDir rulesDir)
    )
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

  # Helper: discover skill dirs containing a SKILL.md
  discoverSkills =
    dir:
    if builtins.pathExists dir then
      builtins.filter (d: builtins.pathExists "${dir}/${d}/SKILL.md") (
        builtins.attrNames (builtins.readDir dir)
      )
    else
      [ ];

  # config/pi/skills/ — pi-specific skills
  piSkillsDir = "${configDir}/pi/skills";
  piSkillDirs = discoverSkills piSkillsDir;
  piSkillLinks = lib.listToAttrs (
    map (d: {
      name = ".pi/agent/skills/${d}/SKILL.md";
      value.source = "${piSkillsDir}/${d}/SKILL.md";
    }) piSkillDirs
  );

  # Note: config/agents/skills/ are managed by agent-skills-nix (skills/flake.nix)
  # which installs them as directory symlinks in ~/.pi/agent/skills/.
  # Do NOT add HM file links for those — they'd conflict with the read-only Nix store dirs.

  skillLinks = piSkillLinks;

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

  # Parse, validate, and optionally inject extra packages at Nix eval time
  piSettingsValidated =
    let
      parsed = builtins.tryEval (builtins.fromJSON piSettingsStripped);
    in
    if !parsed.success then
      builtins.throw "pi settings.jsonc produced invalid JSON after stripping comments/trailing commas. Run: nix eval --expr 'builtins.fromJSON (builtins.readFile ./result-settings.json)' to debug."
    else
      let
        settings = parsed.value;
        withExtras =
          if cfg.extraPackages == [ ] then
            settings
          else
            settings // { packages = settings.packages ++ cfg.extraPackages; };
      in
      builtins.toJSON withExtras;
in
{
  options.modules.shell.pi = {
    enable = mkBoolOpt false;
    memoryRemote = mkOption {
      type = types.str;
      default = "";
      description = "Git remote URL for pi global memory (~/.pi/memory)";
    };
    extraPackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional pi package paths to inject into settings.json packages list";
    };
  };

  config = mkIf cfg.enable {
    # When Ghostty is enabled, add pi-specific keybindings
    # mkAfter ensures pi's shift+enter binding wins over opencode's
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable (mkAfter [
      "${configDir}/ghostty/pi-keybindings.conf"
    ]);

    user.packages = [
      pkgs.llm-agents.pi
      pkgs.llm-agents.beads
      pkgs.bun # still needed for extensions/packages workspace
      pkgs.delta # syntax-highlighted diffs
    ];
    env.BUN_INSTALL = mkDefault "$HOME/.bun";
    env.PATH = mkAfter [ "$HOME/.bun/bin" ];
    # PI_SKIP_VERSION_CHECK already set by llm-agents wrapper, but keep for bun-installed tools
    env.PI_SKIP_VERSION_CHECK = "1";
    # pi-notify sound after system notification
    env.PI_NOTIFY_SOUND_CMD = "afplay /System/Library/Sounds/Hero.aiff";
    # pi-github-tools PAT (from gh CLI)
    env.GITHUB_PAT = "$(gh auth token 2>/dev/null)";
    # pi-tasks backend
    env.PI_TASKS_BACKEND = "beads";

    # Pi configuration via home-manager
    # - config/pi/skills/ + config/agents/skills/ → ~/.pi/agent/skills/
    # - ~/.agents/skills/ auto-discovered by Pi natively (manually installed globals)
    # - AGENTS.md built dynamically from config/agents/rules/*.md
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
            ".pi/agent/extensions/guardrails.json".source = "${configDir}/pi/extensions/guardrails.json";
            ".pi/agent/extensions/process-info.ts".source = "${configDir}/pi/extensions/process-info.ts";
            ".pi/agent/extensions/critique.ts".source = "${configDir}/pi/extensions/critique.ts";
            ".pi/agent/extensions/tmux-status.ts".source = "${configDir}/pi/extensions/tmux-status.ts";
            ".pi/agent/extensions/sub-limits.ts".source = "${configDir}/pi/extensions/sub-limits.ts";
            ".pi/agent/extensions/pi-tool-display/config.json".text = builtins.toJSON {
              # Legacy keys (older pi-tool-display versions)
              registerReadToolOverride = false;
              registerBashToolOverride = false;
              # Current key (v0.9+)
              registerToolOverrides = {
                read = false;
                bash = false;
              };
            };

            ".pi/agent/extensions/you-are-right-killer.ts".source =
              "${configDir}/pi/extensions/you-are-right-killer.ts";
            ".pi/agent/rtk-config.json".source = "${configDir}/pi/extensions/rtk-config.json";

            # Nix-built node_modules for pi-packages with npm dependencies
            # Source stays mutable in pi-packages/, only deps are store-managed
            ".config/dotfiles/pi-packages/pi-agentmap/node_modules".source =
              "${piPkgDeps.pi-agentmap}/node_modules";
            ".config/dotfiles/pi-packages/pi-dcp/node_modules".source = "${piPkgDeps.pi-dcp}/node_modules";
            ".config/dotfiles/pi-packages/pi-scurl/node_modules".source = "${piPkgDeps.pi-scurl}/node_modules";
          };

        # Clean stale local extensions that conflict with package-provided ones
        home.activation.pi-extension-conflict-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ext_dir="$HOME/.pi/agent/extensions"
          rm -f "$ext_dir/context.ts" "$ext_dir/context.js"
        '';

        home.activation.pi-memory-remote = lib.mkIf (cfg.memoryRemote != "") (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            pi_mem="$HOME/.pi/memory"
            if [ -d "$pi_mem/.git" ]; then
              cur=$(${pkgs.git}/bin/git -C "$pi_mem" remote get-url origin 2>/dev/null || true)
              if [ "$cur" != "${cfg.memoryRemote}" ]; then
                ${pkgs.git}/bin/git -C "$pi_mem" remote set-url origin "${cfg.memoryRemote}" 2>/dev/null \
                  || ${pkgs.git}/bin/git -C "$pi_mem" remote add origin "${cfg.memoryRemote}"
                echo "pi memory remote set to ${cfg.memoryRemote}"
              fi
            fi
          ''
        );

        # QMD depends on native modules (better-sqlite3/sqlite-vec), so install
        # its local package deps in the mutable repo instead of a Nix-store
        # node_modules symlink.
        home.activation.pi-qmd-deps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          pkg_dir="$HOME/.config/dotfiles/pi-packages/pi-qmd"
          lock_file="$pkg_dir/package-lock.json"
          stamp_file="$pkg_dir/.node-modules-lock-sha256"
          npm_bin="${pkgs.nodejs}/bin/npm"
          node_bin_dir="${pkgs.nodejs}/bin"
          sha_bin="${pkgs.coreutils}/bin/sha256sum"

          if [ -f "$lock_file" ] && [ -x "$npm_bin" ]; then
            current_sha="$($sha_bin "$lock_file" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
            saved_sha="$(cat "$stamp_file" 2>/dev/null || true)"
            needs_install=0

            if [ ! -d "$pkg_dir/node_modules/@tobilu/qmd" ]; then
              needs_install=1
            elif [ "$current_sha" != "$saved_sha" ]; then
              needs_install=1
            fi

            if [ -L "$pkg_dir/node_modules" ]; then
              rm -f "$pkg_dir/node_modules"
              needs_install=1
            fi

            if [ "$needs_install" -eq 1 ]; then
              echo "Installing pi-qmd npm deps..."
              (cd "$pkg_dir" && PATH="$node_bin_dir:$PATH" "$npm_bin" ci --workspaces=false --omit=dev) || echo "Warning: pi-qmd npm install failed."
              printf '%s\n' "$current_sha" > "$stamp_file"
            fi
          fi
        '';

        # Pi binary now provided by pkgs.llm-agents.pi (nix-managed).
        # Pi-package deps now provided via Nix-built node_modules (home.file symlinks above).
        # This activation handles remaining bun-dependent extras only.
        home.activation.pi-extras = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          bun_bin="${pkgs.bun}/bin/bun"
          if [ -x "$bun_bin" ]; then
            bun_install_dir="''${BUN_INSTALL:-$HOME/.bun}"
            if [ ! -x "$bun_install_dir/bin/gitnexus" ]; then
              echo "Installing gitnexus..."
              "$bun_bin" install -g gitnexus \
                || echo "Warning: gitnexus install failed."
            fi
            # Suppress bun "No license field" warning on ~/package.json
            if [ -f "$HOME/package.json" ] && ! grep -q '"license"' "$HOME/package.json"; then
              ${pkgs.jq}/bin/jq '. + {license: "UNLICENSED"}' "$HOME/package.json" > "$HOME/package.json.tmp" \
                && mv "$HOME/package.json.tmp" "$HOME/package.json"
            fi
          fi
        '';
      };
  };
}
