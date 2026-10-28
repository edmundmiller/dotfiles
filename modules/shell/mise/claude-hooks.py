"""Register mise-trust-worktree in Claude Code's live settings hooks.

The settings template cannot carry these hooks: the Claude activation keeps the
live file's hooks over the template's. binDir is a store path that changes per
rebuild, so earlier registrations are matched by command suffix.
"""

import json
import pathlib
import sys

SUFFIX = "/mise-trust-worktree --hook"
EVENTS = {
    "SessionStart": {"matcher": ""},
    "CwdChanged": {},
    "PostToolUseFailure": {"matcher": "Bash"},
}

path = pathlib.Path(sys.argv[1])
# An empty command removes our registrations, for when mise is disabled.
command = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except (OSError, ValueError):
    raise SystemExit(0)
if not isinstance(data, dict):
    raise SystemExit(0)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = data["hooks"] = {}


def ours(hook):
    return isinstance(hook, dict) and str(hook.get("command", "")).endswith(SUFFIX)


before = json.dumps(hooks, sort_keys=True)
for event, entries in list(hooks.items()):
    if not isinstance(entries, list):
        continue
    kept = []
    for entry in entries:
        if isinstance(entry, dict) and isinstance(entry.get("hooks"), list):
            remaining = [hook for hook in entry["hooks"] if not ours(hook)]
            if len(remaining) < len(entry["hooks"]):
                if not remaining:
                    continue
                entry = {**entry, "hooks": remaining}
        kept.append(entry)
    if kept:
        hooks[event] = kept
    elif entries:
        del hooks[event]

if command:
    for event, fields in EVENTS.items():
        hooks.setdefault(event, []).append(
            {**fields, "hooks": [{"type": "command", "command": command}]}
        )

if json.dumps(hooks, sort_keys=True) != before:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
