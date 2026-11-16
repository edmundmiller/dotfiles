"""Drop Claude hook entries whose command can no longer run."""

import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
hooks_dir = path.parent / "hooks"
STALE_GIT_AI = "/Users/emiller/.git-ai/bin/git-ai checkpoint claude --hook-input stdin"
# Repo-managed hooks are registered in exactly this form. The bootstrap keeps
# the runtime's hook list, so an entry outlives the file it points at.
MANAGED_PREFIX = "$HOME/.claude/hooks/"


def is_stale(hook):
    command = hook.get("command") if isinstance(hook, dict) else None
    if not isinstance(command, str):
        return False
    if command == STALE_GIT_AI:
        return True
    name = command.removeprefix(MANAGED_PREFIX)
    return (
        command.startswith(MANAGED_PREFIX)
        and name
        and "/" not in name
        and " " not in name
        and not (hooks_dir / name).exists()
    )


if hooks_dir.is_dir():
    for link in hooks_dir.iterdir():
        if link.is_symlink() and not link.exists():
            link.unlink()

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

hooks = data.get("hooks") if isinstance(data, dict) else None
changed = False
if isinstance(hooks, dict):
    for event, entries in list(hooks.items()):
        if not isinstance(entries, list):
            continue
        next_entries = []
        for entry in entries:
            hook_list = entry.get("hooks") if isinstance(entry, dict) else None
            if not isinstance(hook_list, list):
                next_entries.append(entry)
                continue
            kept = [hook for hook in hook_list if not is_stale(hook)]
            if kept != hook_list:
                changed = True
            if kept:
                next_entries.append({**entry, "hooks": kept})
        if next_entries:
            hooks[event] = next_entries
        else:
            hooks.pop(event, None)
            changed = True

if changed:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
