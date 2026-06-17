{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.claude;
  inherit (config.dotfiles) configDir;

  # Dynamically concatenate all rule files from config/agents/rules/
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f && f != "AGENTS.md") (
      builtins.attrNames (builtins.readDir rulesDir)
    )
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;
in
{
  options.modules.agents.claude = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [
      pkgs.llm-agents.claude-code
      pkgs.my.codegraph
    ];

    home.file = {
      # Skills and agents are shared across all agents (Claude, OpenCode, Pi)
      # Single source of truth in config/agents/
      ".claude/agents".source = "${configDir}/agents/modes";
      # CLAUDE.md is built dynamically from config/agents/rules/*.md
      ".claude/CLAUDE.md".text = concatenatedRules;

      # WakaTime configuration (reads agenix secret from current user's HOME)
      # NOTE: api_key_vault_cmd is argv-split by wakatime-cli (not shell-parsed),
      # so avoid sh -c with single quotes or it breaks with unmatched-quote errors.
      ".wakatime.cfg" = mkIf pkgs.stdenv.isDarwin {
        text = ''
          [settings]
          api_key_vault_cmd = cat ${config.user.home}/.local/share/agenix/wakatime-api-key
        '';
      };
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.claude-settings-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${pkgs.python3}/bin/python3 - "$HOME/.claude/settings.json" "${configDir}/claude/settings.json" <<'PY'
          import json
          import os
          import pathlib
          import sys

          target = pathlib.Path(sys.argv[1])
          template = pathlib.Path(sys.argv[2])
          target.parent.mkdir(parents=True, exist_ok=True)

          try:
              data = json.loads(template.read_text(encoding="utf-8"))
          except Exception:
              data = {}

          try:
              existing = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
          except Exception:
              existing = {}

          # Herdr's Claude installer mutates settings.json to register hooks.
          # Keep those runtime hooks while refreshing the rest from the repo
          # template, and replace old Home Manager symlinks with a writable file.
          if isinstance(existing, dict) and existing.get("hooks"):
              data["hooks"] = existing["hooks"]

          stale_git_ai = "/Users/emiller/.git-ai/bin/git-ai checkpoint claude --hook-input stdin"
          hooks = data.get("hooks")
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

        home.activation.claude-skills-bridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.claude"
          rm -rf "$HOME/.claude/skills"
          ln -sfn "$HOME/.agents/skills" "$HOME/.claude/skills"
        '';

        home.activation.claude-stale-hook-cleanup = lib.hm.dag.entryAfter [ "herdr-agent-integrations" ] ''
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
        '';

        home.activation.claude-codegraph-mcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    ${pkgs.python3}/bin/python3 - "$HOME/.claude.json" <<'PY'
          import json
          import pathlib
          import sys

          path = pathlib.Path(sys.argv[1])
          try:
              data = json.loads(path.read_text(encoding="utf-8"))
          except Exception:
              data = {}

          if not isinstance(data, dict):
              data = {}

          server = {
              "type": "stdio",
              "command": "codegraph",
              "args": ["serve", "--mcp"],
          }
          servers = data.setdefault("mcpServers", {})
          if servers.get("codegraph") != server:
              servers["codegraph"] = server
              path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
          PY
        '';
      };
  };
}
