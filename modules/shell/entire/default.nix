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
  cfg = config.modules.shell.entire;
in
{
  options.modules.shell.entire = {
    enable = mkBoolOpt false;
    integrations = {
      claude.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically add entire hooks to Claude Code settings when
          `modules.agents.claude.enable` is true.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    homebrew = mkIf isDarwin {
      taps = [ "entireio/tap" ];
      brews = [ "entireio/tap/entire" ];
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.entire-claude-integration =
          mkIf (cfg.integrations.claude.enable && config.modules.agents.claude.enable)
            (
              lib.hm.dag.entryAfter [ "writeBoundary" "claude-settings-bootstrap" ] ''
                ${pkgs.python3}/bin/python3 - "$HOME/.claude/settings.json" <<'PY'
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

                hooks = data.setdefault("hooks", {})

                def upsert_hook(event, matcher, command):
                    entries = hooks.setdefault(event, [])
                    for entry in entries:
                        for h in entry.get("hooks", []):
                            if h.get("command") == command:
                                return
                    entries.append({
                        "matcher": matcher,
                        "hooks": [{"type": "command", "command": command}],
                    })

                upsert_hook("Stop", "", "entire hooks claude-code stop")
                upsert_hook("SessionStart", "", "entire hooks claude-code session-start")
                upsert_hook("SessionEnd", "", "entire hooks claude-code session-end")
                upsert_hook("UserPromptSubmit", "", "entire hooks claude-code user-prompt-submit")
                upsert_hook("PreToolUse", "Task", "entire hooks claude-code pre-task")
                upsert_hook("PostToolUse", "Task", "entire hooks claude-code post-task")
                upsert_hook("PostToolUse", "TodoWrite", "entire hooks claude-code post-todo")

                path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
                PY
              ''
            );
      };
  };
}
