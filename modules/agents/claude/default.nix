{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.claude;
  inherit (config.dotfiles) configDir;

  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      git
      jq
    ];
    text = builtins.readFile "${configDir}/claude/statusline.sh";
  };

  # Warns about oversized context, generation count, and stale resumes. Python
  # keeps the transcript parsing readable; the wrapper pins the interpreter the
  # hook runs with.
  sessionBudgetScript = pkgs.writeText "claude-session-budget.py" (
    builtins.readFile "${configDir}/claude/session-budget-hook.py"
  );

  sessionBudgetHook = pkgs.writeShellApplication {
    name = "claude-session-budget";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${sessionBudgetScript} "$@"
    '';
  };

  sessionBudgetCommand = "$HOME/.claude/hooks/session-budget";

  agentCore = builtins.readFile "${configDir}/agents/core.md";

  # Claude only auto-loads CLAUDE.md. Tell it to fall back to a repo's
  # AGENTS.md so repos that standardize on that file still get read.
  claudeAgentsFileFallback = ''
    # Agents file

    If no `CLAUDE.md` file is found in the root of the repo, check if there is a root-level
    `AGENTS.md`. If there is, read it and treat it as if it were a `CLAUDE.md` file.

    # Pstack

    Pstack playbooks do not grant authority for external writes or deployment.
    The plugin is Nix-managed and read-only. Before running a bundled TypeScript
    helper, copy the entire poteto-mode scripts directory to a fresh writable
    temporary directory and make the copy user-writable. Run the helper from
    the task's working directory using the copied script's absolute path.
    Its Bun bootstrap may install frozen-lockfile dependencies only in that
    temporary copy and only when network access is allowed. Remove it afterward.
  '';
in
{
  options.modules.agents.claude = {
    enable = mkBoolOpt false;
    pstack.enable = mkBoolOpt cfg.enable;
  };

  config = mkIf (cfg.enable || cfg.pstack.enable) {
    user.packages = mkIf cfg.enable [
      pkgs.llm-agents.claude-code
    ];

    home.file =
      optionalAttrs cfg.enable {
        # Shared agent modes come from config/agents/.
        ".claude/agents".source = "${configDir}/agents/modes";
        # Claude's global instruction file receives the same bounded semantic core.
        ".claude/CLAUDE.md".text = agentCore + "\n" + claudeAgentsFileFallback;
        ".claude/statusline.sh".source = "${statusline}/bin/claude-statusline";
        ".claude/hooks/session-budget".source = "${sessionBudgetHook}/bin/claude-session-budget";
      }
      // optionalAttrs cfg.pstack.enable {
        ".claude/pstack-marketplace".source = inputs.skills-catalog.inputs.pstack.outPath;
      };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        # Claude does not discover ~/.agents/skills natively. Expose the shared
        # skills it needs through Claude's own directory. OMP may scan both
        # providers, but name-based discovery keeps one canonical entry.
        home.activation.claude-shared-skill-links = mkIf cfg.enable (
          lib.hm.dag.entryAfter
            [
              "remove-legacy-claude-skills"
              "dotfiles-agent-skills"
            ]
            ''
              ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude/skills"
              for skill in test-quality github-cli-media lore pe-verify; do
                shared="$HOME/.agents/skills/$skill"
                if [ ! -f "$shared/SKILL.md" ]; then
                  echo "ERROR: shared skill is missing: $shared/SKILL.md" >&2
                  exit 1
                fi
                ${pkgs.coreutils}/bin/ln -sfn \
                  "$shared" \
                  "$HOME/.claude/skills/$skill"
                if [ ! -f "$HOME/.claude/skills/$skill/SKILL.md" ]; then
                  echo "ERROR: Claude skill link did not resolve: $skill" >&2
                  exit 1
                fi
              done
            ''
        );

        home.activation.claude-settings-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${pkgs.python3}/bin/python3 - "$HOME/.claude/settings.json" "${configDir}/claude/settings.json" "${boolToString cfg.enable}" "${boolToString cfg.pstack.enable}" <<'PY'
          import copy
          import json
          import os
          import pathlib
          import sys

          target = pathlib.Path(sys.argv[1])
          template = pathlib.Path(sys.argv[2])
          managed_settings = sys.argv[3] == "true"
          pstack_enabled = sys.argv[4] == "true"
          target.parent.mkdir(parents=True, exist_ok=True)

          try:
              data = json.loads(template.read_text(encoding="utf-8"))
          except Exception:
              data = {}

          try:
              existing = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
          except Exception:
              if not managed_settings:
                  raise
              existing = {}

          if not managed_settings:
              # Plugin-only hosts retain their existing permissions and settings.
              template_data = data
              data = copy.deepcopy(existing)
              for key, name in (
                  ("extraKnownMarketplaces", "cursor-plugins"),
                  ("enabledPlugins", "pstack@cursor-plugins"),
              ):
                  data.setdefault(key, {})[name] = template_data[key][name]

          if pstack_enabled:
              data["extraKnownMarketplaces"]["cursor-plugins"]["source"]["path"] = str(
                  target.parent / "pstack-marketplace"
              )
          else:
              data["extraKnownMarketplaces"].pop("cursor-plugins", None)
              data["enabledPlugins"].pop("pstack@cursor-plugins", None)

          # Herdr's Claude installer mutates settings.json to register hooks.
          # Keep those runtime hooks while refreshing the rest from the repo
          # template, and replace old Home Manager symlinks with a writable file.
          if isinstance(existing, dict) and existing.get("hooks"):
              data["hooks"] = existing["hooks"]

          stale_git_ai = "/Users/emiller/.git-ai/bin/git-ai checkpoint claude --hook-input stdin"
          hooks = data.get("hooks") if managed_settings else None
          if isinstance(hooks, dict):
              for event, entries in list(hooks.items()):
                  if not isinstance(entries, list):
                      continue
                  next_entries = []
                  for entry in entries:
                      if not isinstance(entry, dict):
                          next_entries.append(entry)
                          continue
                      hook_list = entry.get("hooks")
                      if not isinstance(hook_list, list):
                          next_entries.append(entry)
                          continue
                      filtered_hooks = [
                          hook
                          for hook in hook_list
                          if not (
                              isinstance(hook, dict)
                              and hook.get("command") == stale_git_ai
                          )
                      ]
                      if filtered_hooks:
                          entry = dict(entry)
                          entry["hooks"] = filtered_hooks
                          next_entries.append(entry)
                  if next_entries:
                      hooks[event] = next_entries
                  else:
                      hooks.pop(event, None)

          if target.is_symlink() or not target.exists() or existing != data:
              tmp = target.with_suffix(target.suffix + ".tmp")
              tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
              if target.exists() or target.is_symlink():
                  target.unlink()
              tmp.replace(target)

          os.chmod(target, 0o600)
          PY
        '';

        # The bootstrap keeps whatever hooks the runtime already registered and
        # drops the template's, so repo-managed hooks are upserted next to
        # Herdr's instead of being declared in config/claude/settings.json.
        home.activation.claude-session-budget-hooks = mkIf cfg.enable (
          lib.hm.dag.entryAfter [ "writeBoundary" "claude-settings-bootstrap" ] ''
            ${pkgs.python3}/bin/python3 - "$HOME/.claude/settings.json" '${sessionBudgetCommand}' <<'PY'
            import json
            import pathlib
            import sys

            path = pathlib.Path(sys.argv[1])
            command = sys.argv[2]
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                data = {}
            if not isinstance(data, dict):
                data = {}

            hooks = data.get("hooks")
            if not isinstance(hooks, dict):
                hooks = {}
                data["hooks"] = hooks

            changed = False
            events = (("SessionStart", "resume"), ("UserPromptSubmit", None), ("Stop", None))
            for event, matcher in events:
                entries = hooks.setdefault(event, [])
                if not isinstance(entries, list) or any(
                    hook.get("command") == command
                    for entry in entries
                    if isinstance(entry, dict)
                    for hook in entry.get("hooks", [])
                    if isinstance(hook, dict)
                ):
                    continue
                entry = {"hooks": [{"type": "command", "command": command}]}
                if matcher:
                    entry["matcher"] = matcher
                entries.append(entry)
                changed = True

            if changed:
                path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            PY
          ''
        );

        home.activation.claude-stale-hook-cleanup = mkIf cfg.enable (
          lib.hm.dag.entryAfter [ "herdr-agent-integrations" ] ''
            ${pkgs.python3}/bin/python3 - "$HOME/.claude/settings.json" <<'PY'
            import json
            import pathlib
            import sys

            path = pathlib.Path(sys.argv[1])
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                raise SystemExit(0)

            stale_git_ai = "/Users/emiller/.git-ai/bin/git-ai checkpoint claude --hook-input stdin"
            hooks = data.get("hooks")
            changed = False
            if isinstance(hooks, dict):
                for event, entries in list(hooks.items()):
                    if not isinstance(entries, list):
                        continue
                    next_entries = []
                    for entry in entries:
                        if not isinstance(entry, dict):
                            next_entries.append(entry)
                            continue
                        hook_list = entry.get("hooks")
                        if not isinstance(hook_list, list):
                            next_entries.append(entry)
                            continue
                        filtered_hooks = [
                            hook
                            for hook in hook_list
                            if not (
                                isinstance(hook, dict)
                                and hook.get("command") == stale_git_ai
                            )
                        ]
                        if filtered_hooks != hook_list:
                            changed = True
                        if filtered_hooks:
                            entry = dict(entry)
                            entry["hooks"] = filtered_hooks
                            next_entries.append(entry)
                    if next_entries:
                        hooks[event] = next_entries
                    else:
                        hooks.pop(event, None)
                        changed = True

            if changed:
                path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            PY
          ''
        );

        home.activation.claude-mcp-cleanup = mkIf cfg.enable (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python3 ${./claude-mcp-cleanup.py} "$HOME/.claude.json"
          ''
        );
      };
  };
}
