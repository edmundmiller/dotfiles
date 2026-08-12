#!/usr/bin/env python3
"""Remove Plannotator commands from writable Codex hooks."""

import argparse
import json
import pathlib
import shlex


def is_plannotator_command(command: object) -> bool:
    if not isinstance(command, str):
        return False
    try:
        executable = shlex.split(command)[0]
    except (IndexError, ValueError):
        return False
    return pathlib.Path(executable).name == "plannotator"


def remove_plannotator_hooks(path: pathlib.Path) -> None:
    if not path.exists():
        return

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return
    stop_entries = hooks.get("Stop")
    if not isinstance(stop_entries, list):
        return

    changed = False
    cleaned_entries: list[object] = []
    for entry in stop_entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
            cleaned_entries.append(entry)
            continue
        commands = entry["hooks"]
        cleaned_commands = [
            hook
            for hook in commands
            if not (
                isinstance(hook, dict)
                and is_plannotator_command(hook.get("command"))
            )
        ]
        if len(cleaned_commands) != len(commands):
            changed = True
        if cleaned_commands:
            cleaned_entry = dict(entry)
            cleaned_entry["hooks"] = cleaned_commands
            cleaned_entries.append(cleaned_entry)

    if not changed:
        return
    hooks["Stop"] = cleaned_entries
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codex-hooks", required=True, type=pathlib.Path)
    args = parser.parse_args()
    remove_plannotator_hooks(args.codex_hooks)


if __name__ == "__main__":
    main()
