# modules/agents/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Auto-discovers prompt templates from config/pi/prompts/
# - Auto-discovers cross-agent shared skills from skills/catalog/
# - Project-local skills should live in .agents/skills/
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
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.pi;
  ghosttyCfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;

  # Pre-built node_modules for packages/pi-packages with npm dependencies
  piPkgDeps = import ./lib/_pi-package-deps.nix {
    inherit pkgs;
    piPkgsDir = ../../../packages/pi-packages;
  };

  secretRefsJson = pkgs.writeText "pi-secret-references.json" (builtins.toJSON cfg.secretReferences);
  honchoEnv = lib.optionalAttrs cfg.honcho.enable (
    {
      HONCHO_ENABLED = "true";
      HONCHO_WORKSPACE_ID = cfg.honcho.workspace;
      HONCHO_PEER_NAME = cfg.honcho.peerName;
      HONCHO_AI_PEER = cfg.honcho.aiPeer;
      HONCHO_SESSION_STRATEGY = cfg.honcho.sessionStrategy;
    }
    // lib.optionalAttrs (cfg.honcho.url != "") {
      HONCHO_URL = cfg.honcho.url;
    }
  );
  honchoEnvJson = pkgs.writeText "pi-honcho-env.json" (builtins.toJSON honchoEnv);
  opBin =
    let
      resolved = builtins.tryEval (lib.getExe pkgs._1password-cli);
    in
    if resolved.success then resolved.value else "op";
  opReadTimeoutSeconds = 15;
  sessionSearchFiles = import ./lib/_session-search-files.nix { inherit lib; };
  dotenvPython = pkgs.python3;
  piRequiredSecretKeys = lib.unique (
    cfg.requiredSecretKeys ++ lib.optionals cfg.honcho.enable [ "HONCHO_API_KEY" ]
  );
  piRequiredSecretKeysJson = pkgs.writeText "pi-required-secret-keys.json" (
    builtins.toJSON piRequiredSecretKeys
  );
  piNodeGypPython = pkgs.python311.withPackages (ps: [ ps.setuptools ]);
  piRuntimePath = lib.makeBinPath [
    pkgs.nodejs
    piNodeGypPython
  ];
  piSecretPreflightScript = pkgs.writeShellScript "pi-secret-preflight" ''
    set -euo pipefail

    dotenv_path="$HOME/.pi/agent/.env"

    ${pkgs.python3}/bin/python3 - ${escapeShellArg piRequiredSecretKeysJson} "$dotenv_path" <<'PY'
    import json
    import os
    import pathlib
    import sys


    required = [key for key in json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")) if key]
    if not required:
        raise SystemExit(0)

    dotenv_path = pathlib.Path(sys.argv[2])
    dotenv_values = {}
    if dotenv_path.exists():
        for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].lstrip()
            key, sep, value = line.partition("=")
            if not sep:
                continue
            dotenv_values[key] = value

    missing = []
    for key in required:
        value = os.environ.get(key)
        if value is None:
            value = dotenv_values.get(key)
        if value is None or value == "":
            missing.append(key)

    if missing:
        print(
            f"error: pi startup blocked; missing required secret env var(s): {', '.join(missing)}",
            file=sys.stderr,
        )
        print(
            f"error: checked process environment and dotenv file: {dotenv_path}",
            file=sys.stderr,
        )
        print(
            "error: unlock 1Password and run `hey re`, or export these env vars before starting pi.",
            file=sys.stderr,
        )
        raise SystemExit(42)
    PY
  '';
  piPackageWithRuntimeWrapper = pkgs.stdenvNoCC.mkDerivation {
    pname = "${pkgs.llm-agents.pi.pname or "pi"}-with-runtime-wrapper";
    version = pkgs.llm-agents.pi.version or "wrapped";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
            runHook preInstall

            cp -a ${pkgs.llm-agents.pi} "$out"
            chmod -R u+w "$out"

            if [ -x "$out/bin/pi" ]; then
              wrapProgram "$out/bin/pi" \
                --run ${escapeShellArg "${piSecretPreflightScript}"} \
                --prefix PATH : ${escapeShellArg piRuntimePath} \
                --set AGENT "1" \
                --set PI_CODING_AGENT "true" \
                --set DEVELOPER_DIR "/Library/Developer/CommandLineTools" \
                --set NPM_CONFIG_PACKAGE_LOCK "false" \
                --set NPM_CONFIG_SAVE "false" \
                --set PYTHON ${escapeShellArg "${piNodeGypPython}/bin/python3"} \
                --unset SDKROOT

              # The pi executable is Nix-managed and cannot self-update in-place.
              # Make the common `pi update` shortcut update only user packages/extensions;
              # explicit self-update requests like `pi update pi` still pass through and fail loudly.
              substituteInPlace "$out/bin/pi" \
                --replace-fail 'exec -a "$0" ' \
                  'if [ "$#" -eq 1 ] && [ "''${1:-}" = "update" ]; then
        set -- update --extensions
      fi
      exec -a "$0" '
            fi

            runHook postInstall
    '';
    inherit (pkgs.llm-agents.pi) meta;
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

  markdownFilesIn =
    dir:
    if builtins.pathExists dir then
      builtins.filter (lib.hasSuffix ".md") (builtins.attrNames (builtins.readDir dir))
    else
      [ ];

  mkPiAgentLinks =
    targetDir: sourceDir: files:
    lib.listToAttrs (
      map (file: {
        name = ".pi/agent/${targetDir}/${file}";
        value.source = "${sourceDir}/${file}";
      }) files
    );

  # Dynamically discover prompt templates from config/pi/prompts/
  promptsDir = "${configDir}/pi/prompts";
  promptLinks = mkPiAgentLinks "prompts" promptsDir (markdownFilesIn promptsDir);

  # Note: skills/catalog/ are managed by agent-skills-nix (skills/flake.nix)
  # and installed to ~/.agents/skills/. Pi discovers that location natively,
  # so do NOT add separate HM skill links under ~/.pi/agent/skills/.

  # Dynamically discover subagent definitions from config/pi/agents/
  # Supports both .md (agents) and .chain.md (chains) for pi-subagents
  agentsDir = "${configDir}/pi/agents";
  agentLinks = mkPiAgentLinks "agents" agentsDir (markdownFilesIn agentsDir);

  # Parse JSONC settings (strips comments and trailing commas via lib.my.readJsonc)
  piSettingsParsedResult = readJsonc "${configDir}/pi/settings.jsonc";
  piSettingsParsed =
    if !piSettingsParsedResult.success then
      builtins.throw "pi settings.jsonc produced invalid JSON after stripping comments/trailing commas. Run: nix eval --expr 'builtins.fromJSON (builtins.readFile ./result-settings.json)' to debug."
    else
      piSettingsParsedResult.value;

  honchoPackage = "npm:@agney/pi-honcho-memory";
  desktopPiHost = ghosttyCfg.enable || config.modules.desktop.macos.enable || isDarwin;

  packageSource =
    pkg:
    if builtins.isString pkg then
      pkg
    else if builtins.isAttrs pkg && pkg ? source then
      pkg.source
    else
      "";

  # Keep module-specific Pi packages tied to the Nix modules that provide the
  # matching runtime. This prevents stale tools/skills from showing up on hosts
  # that do not run that shell integration, and avoids redundant interactive
  # shell prompts when tmux/herdr are the preferred persistent workspace layer.
  moduleManagedPackageGroups = {
    herdr = [ "npm:@ogulcancelik/pi-herdr" ];
    tmux = [
      "npm:pi-tmux-window-name"
      "git:github.com/ogulcancelik/pi-extensions"
      "https://github.com/pasky/pi-side-agents"
    ];
    interactiveShell = [ "npm:pi-interactive-shell" ];
    mcp = [
      "npm:pi-mcp-adapter"
      "npm:pi-mcporter"
    ];
    computerUse = [ "git:github.com/injaneity/pi-computer-use" ];
    gitTools = [
      "npm:@prinova/pi-github-tools"
      "npm:pi-gitnexus"
      "git:github.com/MattDevy/pi-extensions"
    ];
    statusUi = [
      "npm:@marckrenn/pi-sub-bar"
      "~/.pi/agent/extensions/sub-limits.ts"
      "git:github.com/Thinkscape/pi-status"
      "npm:pi-wakatime"
    ];
    contextMemory = [
      "npm:pi-context"
      "npm:pi-total-recall"
    ];
    cursorSdk = [
      # Cursor SDK provider: exposes Cursor models as `cursor/...` in Pi's native model picker.
      # https://github.com/fitchmultz/pi-cursor-sdk
      "npm:pi-cursor-sdk"
    ];
  };

  moduleManagedPackageSources = lib.concatLists (builtins.attrValues moduleManagedPackageGroups);

  dropModuleManagedPackages =
    packages:
    builtins.filter (pkg: !(builtins.elem (packageSource pkg) moduleManagedPackageSources)) packages;

  moduleManagedPackages =
    lib.optionals config.modules.shell.herdr.enable moduleManagedPackageGroups.herdr
    ++ lib.optionals config.modules.shell.tmux.enable [
      # Auto-name tmux windows + session titles from first prompt - https://github.com/default-anton/pi-tmux-window-name
      "npm:pi-tmux-window-name"
      # We're experimenting with tmux pane control for now (bash, capture, send, kill, spawn agents) - https://github.com/ogulcancelik/pi-extensions
      {
        source = "git:github.com/ogulcancelik/pi-extensions";
        extensions = [ "packages/pi-tmux/index.ts" ];
        skills = [ ];
      }
      # Side agents in tmux windows + git worktrees - https://github.com/pasky/pi-side-agents
      "https://github.com/pasky/pi-side-agents"
    ]
    ++ lib.optionals (
      !(config.modules.shell.tmux.enable || config.modules.shell.herdr.enable)
    ) moduleManagedPackageGroups.interactiveShell
    ++ lib.optionals cfg.mcp.enable moduleManagedPackageGroups.mcp
    ++ lib.optionals cfg.computerUse.enable moduleManagedPackageGroups.computerUse
    ++ lib.optionals cfg.gitTools.enable moduleManagedPackageGroups.gitTools
    ++ lib.optionals cfg.statusUi.enable moduleManagedPackageGroups.statusUi
    ++ lib.optionals cfg.contextMemory.enable moduleManagedPackageGroups.contextMemory
    ++ lib.optionals cfg.cursorSdk.enable moduleManagedPackageGroups.cursorSdk;

  piPackagesExtra =
    cfg.extraPackages ++ moduleManagedPackages ++ lib.optionals cfg.honcho.enable [ honchoPackage ];

  piSettingsBase =
    (
      piSettingsParsed
      // {
        packages = dropModuleManagedPackages piSettingsParsed.packages;
        enabledModels = lib.unique cfg.enabledModels;
      }
    )
    // lib.optionalAttrs config.modules.shell.herdr.enable (
      let
        herdrThemeName = config.modules.shell.herdr.piThemeName;
      in
      {
        # Herdr ships a matching high-contrast theme into ~/.pi/agent/themes.
        # Configure it directly in the generated Pi settings so activation does
        # not need to mutate the read-only Home Manager settings symlink.
        # The theme name varies by host (`piThemeVariant`), so read it from
        # the herdr module instead of hardcoding the default name here.
        theme = herdrThemeName;
        themes = [ "${config.user.home}/.pi/agent/themes/${herdrThemeName}.json" ];
      }
    );

  piSettingsWithExtras =
    if piPackagesExtra == [ ] then
      piSettingsBase
    else
      piSettingsBase // { packages = piSettingsBase.packages ++ piPackagesExtra; };

  piSettingsPackageSources = map packageSource piSettingsWithExtras.packages;

  hasPiPackage = source: builtins.elem source piSettingsPackageSources;

  # Guardrails against known duplicate command/tool providers.
  # These collisions currently fail extension loading at startup.
  piConflictAssertions = [
    {
      assertion =
        !(
          hasPiPackage "~/.config/dotfiles/packages/pi-packages/pi-beads"
          && hasPiPackage "npm:@tintinweb/pi-tasks"
        );
      message = "Pi package conflict: both pi-beads and @tintinweb/pi-tasks register /tasks. Keep exactly one authoritative /tasks provider.";
    }
    {
      assertion =
        !(
          hasPiPackage "~/.config/dotfiles/packages/pi-packages/pi-non-interactive"
          && hasPiPackage "git:github.com/lucasmeijer/pi-bash-live-view"
        );
      message = "Pi package conflict: both pi-non-interactive and pi-bash-live-view register tool 'bash'. Keep exactly one authoritative bash provider.";
    }
  ];

  piSettingsValidated = builtins.toJSON piSettingsWithExtras;
in
{
  options.modules.agents.pi = {
    enable = mkBoolOpt false;
    memoryRemote = mkOption {
      type = types.str;
      default = "";
      description = "Git remote URL for pi global memory (~/.pi/memory)";
    };
    enabledModels = mkOption {
      type = types.listOf types.str;
      default = piSettingsParsed.enabledModels or [ ];
      description = "Base Pi models enabled for model cycling. Defaults to config/pi/settings.jsonc.";
    };
    mcp.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Pi MCP adapter and MCPorter packages.";
    };
    computerUse.enable = mkOption {
      type = types.bool;
      default = desktopPiHost;
      description = "Enable Pi GUI/browser computer-use tools on desktop-capable hosts.";
    };
    gitTools.enable = mkOption {
      type = types.bool;
      default = config.modules.shell.git.enable;
      description = "Enable Pi GitHub/GitNexus/git-review packages when shell git tooling is enabled.";
    };
    statusUi.enable = mkOption {
      type = types.bool;
      default = desktopPiHost;
      description = "Enable Pi status, usage quota, and WakaTime UI packages on interactive desktop hosts.";
    };
    contextMemory.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Pi context and total-recall memory/search packages. Honcho has its own toggle.";
    };
    cursorSdk.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the Cursor SDK provider for Pi. Add Cursor models with modules.agents.pi.enabledModels.";
    };
    honcho = {
      enable = mkBoolOpt false;
      workspace = mkOption {
        type = types.str;
        default = "hermes";
        description = "Honcho workspace ID for pi-honcho-memory.";
      };
      peerName = mkOption {
        type = types.str;
        default = "Edmund";
        description = "Human peer name used by pi-honcho-memory.";
      };
      aiPeer = mkOption {
        type = types.str;
        default = "pi";
        description = "AI peer name used by pi-honcho-memory.";
      };
      sessionStrategy = mkOption {
        type = types.enum [
          "repo"
          "git-branch"
          "directory"
        ];
        default = "directory";
        description = "Session scoping strategy for pi-honcho-memory.";
      };
      url = mkOption {
        type = types.str;
        default = "";
        description = "Optional Honcho base URL override for pi-honcho-memory.";
      };
    };
    secretReferences = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "1Password secret references materialized into ~/.pi/agent/.env";
    };
    requiredSecretKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "HONCHO_API_KEY" ];
      description = ''
        Additional pi secrets that must be present at runtime startup.
        Missing required keys fail pi startup in a wrapper preflight, but
        activation/rebuild remains non-fatal.
      '';
    };
    extraPackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional pi package paths to inject into settings.json packages list";
    };
  };

  config = mkIf cfg.enable {
    assertions = piConflictAssertions;

    # When Ghostty is enabled, add pi-specific keybindings
    # mkAfter ensures pi's shift+enter binding wins over opencode's
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable (mkAfter [
      "${configDir}/ghostty/pi-keybindings.conf"
    ]);

    user.packages = [
      piPackageWithRuntimeWrapper
      pkgs.llm-agents."beads-rust"
      pkgs.llm-agents.rtk
      pkgs.llm-agents.toon
      pkgs.llm-agents.zat
      pkgs.bun # still needed for extensions/packages workspace
      pkgs.delta # syntax-highlighted diffs
    ];
    env.BUN_INSTALL = mkDefault "$HOME/.bun";
    env.PATH = mkAfter [ "$HOME/.bun/bin" ];
    # PI_SKIP_VERSION_CHECK already set by llm-agents wrapper, but keep for bun-installed tools
    env.PI_SKIP_VERSION_CHECK = "1";
    # Keep Pi pointed at the nix-managed agent root so package discovery,
    # settings.json, and permission policy files are loaded consistently.
    # Individual writable files (sessions, auth, cache) live alongside the
    # managed symlinks under ~/.pi/agent.
    env.PI_CODING_AGENT_DIR = "$HOME/.pi/agent";
    env.PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR = "$HOME/.pi/agent";
    env.PI_PERMISSION_SYSTEM_CONFIG_PATH = "$HOME/.pi/agent/extensions/pi-permission-system/config.json";
    # pi-notify sound after system notification
    env.PI_NOTIFY_SOUND_CMD = "afplay /System/Library/Sounds/Hero.aiff";
    # pi-github-tools PAT (from gh CLI)
    env.GITHUB_PAT = "$(gh auth token 2>/dev/null)";
    # pi-tasks backend
    env.PI_TASKS_BACKEND = "beads";
    # pi-overwatch dashboard cadence / stale detection
    env.PI_OVERWATCH_REFRESH_MS = "1000";
    env.PI_OVERWATCH_STALE_MS = "20000";
    # pi-computer-use installs its native macOS helper outside the extension
    # checkout at ~/.pi/agent/helpers/pi-computer-use/bridge. Upstream normally
    # preserves an existing modern helper to avoid gratuitous TCC identity
    # churn, but that can leave a stale helper after `pi update --extensions`.
    # Force setup to reconcile the helper with the installed extension version;
    # if the helper actually changes, macOS may require re-granting
    # Accessibility/Screen Recording for the new binary identity.
    env.PI_COMPUTER_USE_FORCE_HELPER_INSTALL = mkIf cfg.computerUse.enable "1";

    environment.shellAliases = {
      nbt = "pi -nbt";
    };

    # Pi configuration via home-manager
    # - skills/catalog/ → ~/.agents/skills/
    # - project-local skills should live in .agents/skills/
    # - ~/.agents/skills/ auto-discovered by Pi natively
    # - AGENTS.md built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.file = import ./lib/_home-files.nix {
          inherit
            builtins
            configDir
            concatenatedRules
            piPkgDeps
            piSettingsValidated
            promptLinks
            agentLinks
            sessionSearchFiles
            isDarwin
            ;
        };

        home.activation = import ./lib/_activation.nix {
          inherit
            cfg
            pkgs
            secretRefsJson
            honchoEnvJson
            opBin
            opReadTimeoutSeconds
            dotenvPython
            escapeShellArg
            ;
          hmLib = lib;
        };
      };
  };
}
