# modules/agents/pi/default.nix
#
# Pi coding agent configuration
# https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
#
# Pi is a terminal-based AI coding assistant. This module:
# - Configures Ghostty keybindings when Ghostty is enabled
# - Auto-discovers prompt templates from config/pi/prompts/
# - Auto-discovers cross-agent shared skills from config/agents/skills/
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
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.pi;
  ghosttyCfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;

  # Pre-built node_modules for pi-packages with npm dependencies
  piPkgDeps = import ./lib/_pi-package-deps.nix {
    inherit pkgs;
    piPkgsDir = ../../../pi-packages;
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
  dotenvPython = pkgs.python3;
  piRequiredSecretKeys = lib.unique (
    cfg.requiredSecretKeys ++ lib.optionals cfg.honcho.enable [ "HONCHO_API_KEY" ]
  );
  piRequiredSecretKeysJson = pkgs.writeText "pi-required-secret-keys.json" (
    builtins.toJSON piRequiredSecretKeys
  );
  piSecretPreflight = pkgs.writeShellScript "pi-secret-preflight" ''
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
  piPackageWithSecretPreflight = pkgs.stdenvNoCC.mkDerivation {
    pname = "${pkgs.llm-agents.pi.pname or "pi"}-with-secret-preflight";
    version = pkgs.llm-agents.pi.version or "wrapped";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall

      cp -a ${pkgs.llm-agents.pi} "$out"
      chmod -R u+w "$out"

      if [ -x "$out/bin/pi" ]; then
        wrapProgram "$out/bin/pi" \
          --run ${escapeShellArg "${piSecretPreflight}"}
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

  # Note: config/agents/skills/ are managed by agent-skills-nix (skills/flake.nix)
  # and installed to ~/.agents/skills/. Pi discovers that location natively,
  # so do NOT add separate HM skill links under ~/.pi/agent/skills/.

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
  piSettingsParsed =
    let
      parsed = builtins.tryEval (builtins.fromJSON piSettingsStripped);
    in
    if !parsed.success then
      builtins.throw "pi settings.jsonc produced invalid JSON after stripping comments/trailing commas. Run: nix eval --expr 'builtins.fromJSON (builtins.readFile ./result-settings.json)' to debug."
    else
      parsed.value;

  honchoPackage = "npm:@agney/pi-honcho-memory";

  piPackagesExtra = cfg.extraPackages ++ lib.optionals cfg.honcho.enable [ honchoPackage ];

  piSettingsWithExtras =
    if piPackagesExtra == [ ] then
      piSettingsParsed
    else
      piSettingsParsed // { packages = piSettingsParsed.packages ++ piPackagesExtra; };

  piSettingsPackageSources = map (
    pkg:
    if builtins.isString pkg then
      pkg
    else if builtins.isAttrs pkg && pkg ? source then
      pkg.source
    else
      ""
  ) piSettingsWithExtras.packages;

  hasPiPackage = source: builtins.elem source piSettingsPackageSources;

  # Guardrails against known duplicate command/tool providers.
  # These collisions currently fail extension loading at startup.
  piConflictAssertions = [
    {
      assertion =
        !(hasPiPackage "~/.config/dotfiles/pi-packages/pi-beads" && hasPiPackage "npm:@tintinweb/pi-tasks");
      message = "Pi package conflict: both pi-beads and @tintinweb/pi-tasks register /tasks. Keep exactly one authoritative /tasks provider.";
    }
    {
      assertion =
        !(
          hasPiPackage "~/.config/dotfiles/pi-packages/pi-non-interactive"
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
      piPackageWithSecretPreflight
      pkgs.llm-agents."beads-rust"
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
    # - config/agents/skills/ → ~/.agents/skills/
    # - project-local skills should live in .agents/skills/
    # - ~/.agents/skills/ auto-discovered by Pi natively
    # - AGENTS.md built dynamically from config/agents/rules/*.md
    # - settings.json stripped of comments (pi only supports standard JSON)
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.file =
          promptLinks
          // agentLinks
          // {
            ".pi/agent/AGENTS.md".text = concatenatedRules;
            ".pi/agent/settings.json".text = piSettingsValidated;
            ".pi/agent/extensions/enforce-commit-signing.ts".source =
              "${configDir}/pi/extensions/enforce-commit-signing.ts";
            # Keep guardrails.json writable for @aliou/pi-guardrails (it opens the file with write access)
            # so we do not manage it as a read-only Nix store symlink.
            ".pi/agent/extensions/process-info.ts".source = "${configDir}/pi/extensions/process-info.ts";
            ".pi/agent/extensions/critique.ts".source = "${configDir}/pi/extensions/critique.ts";
            ".pi/agent/extensions/commit-review.ts".source = "${configDir}/pi/extensions/commit-review.ts";
            ".pi/agent/extensions/review.ts".source = "${configDir}/pi/extensions/review.ts";
            ".pi/agent/extensions/lib/commit-review-logic.ts".source =
              "${configDir}/pi/extensions/lib/commit-review-logic.ts";
            ".pi/agent/extensions/lib/commit-config.ts".source =
              "${configDir}/pi/extensions/lib/commit-config.ts";
            ".pi/agent/extensions/lib/review-git.ts".source = "${configDir}/pi/extensions/lib/review-git.ts";
            ".pi/agent/extensions/lib/review-screen.ts".source =
              "${configDir}/pi/extensions/lib/review-screen.ts";
            ".pi/agent/extensions/generate-commit-message.ts".source =
              "${configDir}/pi/extensions/generate-commit-message.ts";
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

            ".pi/agent/extensions/prompt-url-widget.ts".source =
              "${configDir}/pi/extensions/prompt-url-widget.ts";
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
          rm -rf "$HOME/.cache/npm/lib/node_modules/@howaboua/pi-codex-conversion"
          rmdir "$HOME/.cache/npm/lib/node_modules/@howaboua" 2>/dev/null || true

          # @aliou/pi-guardrails needs this file writable at runtime.
          # If HM wrote a symlink into /nix/store, replace it with a local writable copy.
          guardrails="$ext_dir/guardrails.json"
          if [ -L "$guardrails" ]; then
            tmp="$guardrails.tmp"
            cp -L "$guardrails" "$tmp"
            rm -f "$guardrails"
            mv "$tmp" "$guardrails"
            chmod 0644 "$guardrails"
          fi
        '';

        home.activation.pi-legacy-skill-dir-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -rf "$HOME/.pi/agent/skills"
        '';

        home.activation.pi-dotenv-secrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                              dotenv_target="$HOME/.pi/agent/.env"
                              if [ -s ${escapeShellArg secretRefsJson} ]; then
                                if command -v ${escapeShellArg opBin} >/dev/null 2>&1; then
                                  tmp="$(${pkgs.coreutils}/bin/mktemp)"
                                  ${dotenvPython}/bin/python3 - "$tmp" ${escapeShellArg secretRefsJson} ${escapeShellArg honchoEnvJson} "$dotenv_target" ${escapeShellArg opBin} <<'PY'
          import json
          import os
          import pathlib
          import subprocess
          import sys


          target = pathlib.Path(sys.argv[1])
          refs_path = pathlib.Path(sys.argv[2])
          plain_path = pathlib.Path(sys.argv[3])
          dotenv_path = pathlib.Path(sys.argv[4])
          op_bin = sys.argv[5]

          refs = json.loads(refs_path.read_text(encoding="utf-8"))
          plain = json.loads(plain_path.read_text(encoding="utf-8"))
          managed_keys = set(refs) | set(plain)
          existing_lines = []
          if dotenv_path.exists():
              existing_lines = dotenv_path.read_text(encoding="utf-8").splitlines()

          existing_values = {}
          kept_lines = []
          for line in existing_lines:
              key, sep, rest = line.partition("=")
              if sep:
                  existing_values[key] = rest
              if sep and key in managed_keys:
                  continue
              kept_lines.append(line)

          rendered_lines = list(kept_lines)
          for key, value in plain.items():
              if value:
                  rendered_lines.append(f"{key}={value}")

          failed_keys = []
          empty_keys = []
          preserved_keys = []
          for key, ref in refs.items():
              try:
                  value = subprocess.check_output(
                      [op_bin, "read", ref],
                      text=True,
                      stderr=subprocess.DEVNULL,
                      timeout=15,
                  ).rstrip("\n")
              except Exception:
                  fallback = existing_values.get(key, "")
                  if fallback:
                      preserved_keys.append(f"{key} ({ref})")
                      rendered_lines.append(f"{key}={fallback}")
                      continue
                  failed_keys.append(f"{key} ({ref})")
                  continue

              if not value:
                  fallback = existing_values.get(key, "")
                  if fallback:
                      preserved_keys.append(f"{key} ({ref})")
                      rendered_lines.append(f"{key}={fallback}")
                      continue
                  empty_keys.append(f"{key} ({ref})")
                  continue

              rendered_lines.append(f"{key}={value}")

          if failed_keys:
              sample = ", ".join(failed_keys[:5])
              extra = "" if len(failed_keys) <= 5 else f" (+{len(failed_keys) - 5} more)"
              print(
                  f"warning: failed to read {len(failed_keys)} pi secret(s) from 1Password: {sample}{extra}",
                  file=sys.stderr,
              )

          if empty_keys:
              sample = ", ".join(empty_keys[:5])
              extra = "" if len(empty_keys) <= 5 else f" (+{len(empty_keys) - 5} more)"
              print(
                  f"warning: {len(empty_keys)} pi secret(s) resolved empty from 1Password: {sample}{extra}",
                  file=sys.stderr,
              )

          if preserved_keys:
              sample = ", ".join(preserved_keys[:5])
              extra = "" if len(preserved_keys) <= 5 else f" (+{len(preserved_keys) - 5} more)"
              print(
                  f"warning: preserving {len(preserved_keys)} existing pi secret(s) because 1Password did not return a fresh value: {sample}{extra}",
                  file=sys.stderr,
              )

          content = "\n".join(rendered_lines)
          if content:
              content += "\n"

          target.write_text(content, encoding="utf-8")
          os.chmod(target, 0o600)
          PY
                                  ${pkgs.coreutils}/bin/install -m 0600 "$tmp" "$dotenv_target"
                                  ${pkgs.coreutils}/bin/rm -f "$tmp"
                                else
                                  echo "warning: 1Password CLI unavailable; skipping pi dotenv materialization" >&2
                                fi
                              fi
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
            if [ ! -x "$bun_install_dir/bin/markit" ]; then
              echo "Installing markit..."
              "$bun_bin" install -g markit-ai \
                || echo "Warning: markit install failed."
            fi
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
