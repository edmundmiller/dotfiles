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
  rexJj = pkgs.writeShellScriptBin "rex-jj" ''
    exec ${pkgs.python3}/bin/python3 ${../../config/rex/jj-workspace.py} "$@"
  '';
  undoRoot = "${pkgs.my.rex-undo}/share/rex-undo-extension";
  # Config loads outside a login shell, without env.zsh's app-bundle PATH.
  undoRex = pkgs.writeShellScript "rex-undo-rex" ''
    if command -v rex >/dev/null 2>&1; then exec rex "$@"; fi
    for cli in \
      "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" \
      "$HOME/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" \
      "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"; do
      if [ -x "$cli" ]; then exec "$cli" "$@"; fi
    done
    echo "rex-undo: cannot find the Rex CLI" >&2
    exit 127
  '';
  undoSetup = optionalString isDarwin ''
    dofile("${undoRoot}/rex-undo/undo.lua").setup{
      dir = "${undoRoot}/rex-undo",
      rex = "${undoRex}",
      key = "cmd+shift+t",
      history = 50,
    }
  '';
  undoHook = pkgs.writeShellScript "rex-undo-claude-session-start" ''
    exec /bin/sh ${undoRoot}/hooks/claude-session-start.sh
  '';
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
        SessionStart = [
          "idle"
          ""
        ];
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
        SessionStart = [
          "idle"
          ""
        ];
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
      # The Rex app (currently macOS-only) is installed separately. Nix owns its config
      # and installs neorex on Darwin.
      # The Linux Rex server is configured separately through services.rex.
      home.configFile."rex/init.lua".text =
        builtins.replaceStrings [ "@rexJj@" "-- @rexUndo@" ] [ "${rexJj}/bin/rex-jj" undoSetup ]
          (builtins.readFile "${config.dotfiles.configDir}/rex/init.lua");
      "user.packages" = [ rexJj ] ++ optionals isDarwin [ pkgs.my.neorex ];
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
            ${pkgs.python3}/bin/python3 - "$HOME" ${lib.escapeShellArg agentStatusCmd} ${lib.escapeShellArg agentHooks} ${lib.escapeShellArg (toString undoHook)} <<'PY'
            import json, pathlib, sys

            home, cmd, spec, undo_hook = pathlib.Path(sys.argv[1]), sys.argv[2], json.loads(sys.argv[3]), sys.argv[4]
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
                            and not (agent == "claude" and event == "SessionStart" and (
                                "rex-undo-claude-session-start" in h.get("command", "")
                                or ("rex-undo" in h.get("command", "") and "claude-session-start.sh" in h.get("command", ""))
                            ))
                        ]
                        if entry["hooks"]:
                            entries.append(entry)
                    command = f"{cmd} {agent} {state}" + (f" '{msg}'" if msg else "")
                    entries.append({"hooks": [{"type": "command", "command": command, "timeout": 5}]})
                    if agent == "claude" and event == "SessionStart":
                        entries.append({"hooks": [{"type": "command", "command": undo_hook, "timeout": 5}]})
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
