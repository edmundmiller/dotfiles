"""Remove legacy Herdr agent integrations on native-backend hosts.

Native Herdr learns agent status from OSC 7501 reports. The socket hooks and
plugins written by `herdr integration install` exit early outside the legacy
backend, so they are dead weight here. Other hooks and plugins are preserved.

Usage: legacy-agent-cleanup.py HOME AGENT...
"""

import json
import pathlib
import re
import sys

def write_json(path, data):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def drop_hook_commands(path, script):
    """Remove hook commands that run `script` from a Claude/Codex hooks file."""
    if not path.is_file() or path.is_symlink():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    hooks = data.get("hooks") or {}
    changed = False
    for event, entries in list(hooks.items()):
        kept = []
        for entry in entries:
            hook_list = [
                hook
                for hook in entry.get("hooks", [])
                if str(script) not in hook.get("command", "")
            ]
            changed |= hook_list != entry.get("hooks", [])
            if hook_list:
                kept.append({**entry, "hooks": hook_list})
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event)
    if changed:
        write_json(path, data)


def strip_jsonc(text):
    """Drop // and /* */ comments outside strings; tui.jsonc is otherwise JSON."""
    pattern = r'("(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/'
    return re.sub(pattern, lambda m: m.group(1) or "", text, flags=re.S)


def claude(home):
    script = home / ".claude" / "hooks" / "herdr-agent-state.sh"
    drop_hook_commands(home / ".claude" / "settings.json", script)
    script.unlink(missing_ok=True)


def codex(home):
    script = home / ".codex" / "herdr-agent-state.sh"
    drop_hook_commands(home / ".codex" / "hooks.json", script)
    script.unlink(missing_ok=True)


def opencode(home):
    root = home / ".config" / "opencode"
    tui = root / "tui.jsonc"
    if tui.is_symlink():
        return
    data = json.loads(strip_jsonc(tui.read_text(encoding="utf-8"))) if tui.is_file() else {}
    plugins = [p for p in data.get("plugin", []) if "herdr-tui-session" not in str(p)]
    if data.get("plugin", []) != plugins:
        data["plugin"] = plugins
        write_json(tui, data)
    (root / "herdr-tui-session.js").unlink(missing_ok=True)
    (root / "plugins" / "herdr-agent-state.js").unlink(missing_ok=True)


def main():
    home = pathlib.Path(sys.argv[1])
    for agent in sys.argv[2:]:
        {"claude": claude, "codex": codex, "opencode": opencode}[agent](home)


if __name__ == "__main__":
    main()
