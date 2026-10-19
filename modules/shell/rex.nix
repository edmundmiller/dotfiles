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
  cfg = config.modules.shell.rex;
  themeFile =
    {
      catppuccin = ../../config/rex/themes-catppuccin.json;
      seqera = ../../config/rex/themes-seqera.json;
    }
    .${config.modules.desktop.term.themeStack.variant};
  agentStatus = pkgs.writeTextFile {
    name = "rex-agent-status";
    destination = "/bin/rex-agent-status";
    executable = true;
    text = builtins.readFile ../../config/rex/hooks/agent-status.sh;
  };
  agentStatusCmd = "${agentStatus}/bin/rex-agent-status";
  # Agent -> hook event -> [ state, message ] for Rex's OSC 7501 program status.
  agentHooks = builtins.toJSON {
    claude = {
      file = ".claude/settings.json";
      events = {
        UserPromptSubmit = [
          "working"
          ""
        ];
        PreToolUse = [
          "working"
          ""
        ];
        Notification = [
          "blocked"
          "Needs attention"
        ];
        Stop = [
          "done"
          ""
        ];
        SessionEnd = [
          "clear"
          ""
        ];
      };
    };
    codex = {
      file = ".codex/hooks.json";
      events = {
        UserPromptSubmit = [
          "working"
          ""
        ];
        PostToolUse = [
          "working"
          ""
        ];
        PermissionRequest = [
          "blocked"
          "Needs approval"
        ];
        Stop = [
          "done"
          ""
        ];
      };
    };
  };
  themeIDs = listToAttrs (
    map (theme: nameValuePair theme.appearance theme.id) (
      builtins.fromJSON (builtins.readFile themeFile)
    )
  );
in
{
  options.modules.shell.rex.enable = mkBoolOpt false;

  config = mkIf cfg.enable (
    {
      # The Rex app (currently macOS-only) is installed separately. Nix owns only its config.
      # The Linux Rex server is configured separately through services.rex.
      home.configFile."rex/init.lua".source = "${config.dotfiles.configDir}/rex/init.lua";
      modules.agents.mcp.servers.superlogical.enable = mkDefault true;
    }
    // optionalAttrs isDarwin {
      system.defaults.CustomUserPreferences."com.superlogical.rex" = {
        "Workspace.tabStyle" = "vertical";
        "Workspace.lightThemeID" = themeIDs.light;
        "Workspace.darkThemeID" = themeIDs.dark;
      };

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          # Rex stores imported themes as JSON inside NSData, not a plist array.
          # Merge Rex status hooks into the runtime-mutated Claude and Codex hook
          # files. Existing hooks are kept; stale rex-agent-status entries are replaced.
          home.activation.rexAgentStatusHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python3 - "$HOME" ${lib.escapeShellArg agentStatusCmd} ${lib.escapeShellArg agentHooks} <<'PY'
            import json, pathlib, sys

            home, cmd, spec = pathlib.Path(sys.argv[1]), sys.argv[2], json.loads(sys.argv[3])
            for agent, conf in spec.items():
                path = home / conf["file"]
                if not path.is_file() or path.is_symlink():
                    continue
                data = json.loads(path.read_text(encoding="utf-8"))
                hooks = data.setdefault("hooks", {})
                for event, (state, msg) in conf["events"].items():
                    entries = []
                    for entry in hooks.get(event, []):
                        entry["hooks"] = [
                            h for h in entry.get("hooks", [])
                            if "rex-agent-status" not in h.get("command", "")
                        ]
                        if entry["hooks"]:
                            entries.append(entry)
                    command = f"{cmd} {agent} {state}" + (f" '{msg}'" if msg else "")
                    entries.append({"hooks": [{"type": "command", "command": command, "timeout": 5}]})
                    hooks[event] = entries
                tmp = path.with_suffix(path.suffix + ".tmp")
                tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
                tmp.replace(path)
            PY
          '';

          home.activation.rexThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run /usr/bin/defaults write com.superlogical.rex Workspace.customThemes -data \
              "$(/usr/bin/xxd -p ${themeFile} | /usr/bin/tr -d '\n')"
          '';
        };
    }
  );
}
