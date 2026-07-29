#!/usr/bin/env python3
"""Merge Plannotator into writable Codex configuration."""

import argparse
import json
import pathlib
import shlex


def enable_codex_hooks(path: pathlib.Path) -> None:
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    output: list[str] = []
    in_features = False
    found_features = False
    found_hooks = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_features and not found_hooks:
                output.append("hooks = true")
                found_hooks = True
            in_features = stripped == "[features]"
            found_features = found_features or in_features
            output.append(line)
            continue

        key = stripped.partition("=")[0].strip()
        if in_features and key in {"hooks", "codex_hooks"}:
            if not found_hooks:
                output.append("hooks = true")
                found_hooks = True
            continue

        output.append(line)

    if in_features and not found_hooks:
        output.append("hooks = true")
    elif not found_features:
        if output and output[-1] != "":
            output.append("")
        output.extend(("[features]", "hooks = true"))

    write_text(path, "\n".join(output).rstrip() + "\n")


def is_plannotator_command(command: object) -> bool:
    if not isinstance(command, str):
        return False
    try:
        executable = shlex.split(command)[0]
    except (IndexError, ValueError):
        return False
    return pathlib.Path(executable).name == "plannotator"


def merge_codex_hook(path: pathlib.Path, command: str) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    except (json.JSONDecodeError, OSError):
        data = {}
    if not isinstance(data, dict):
        data = {}

    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        hooks = {}
        data["hooks"] = hooks
    stop_entries = hooks.setdefault("Stop", [])
    if not isinstance(stop_entries, list):
        stop_entries = []
        hooks["Stop"] = stop_entries

    configured = False
    for entry in stop_entries:
        if not isinstance(entry, dict):
            continue
        commands = entry.get("hooks")
        if not isinstance(commands, list):
            continue
        for hook in commands:
            if not isinstance(hook, dict) or not is_plannotator_command(
                hook.get("command")
            ):
                continue
            hook.update(
                {
                    "type": "command",
                    "command": command,
                    "timeout": 345600,
                }
            )
            configured = True
            break
        if configured:
            break

    if not configured:
        stop_entries.append(
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": command,
                        "timeout": 345600,
                    }
                ]
            }
        )

    write_text(path, json.dumps(data, indent=2) + "\n")


def write_text(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codex-config", required=True, type=pathlib.Path)
    parser.add_argument("--codex-hooks", required=True, type=pathlib.Path)
    parser.add_argument("--command", required=True)
    args = parser.parse_args()

    enable_codex_hooks(args.codex_config)
    merge_codex_hook(args.codex_hooks, args.command)


if __name__ == "__main__":
    main()
