import json
import os
import re
import sys
import tempfile
from pathlib import Path


VAULT = Path.home() / "obsidian-vault"
GUARD_NAME = "codex-vault-restore-guard"
DENIAL = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            "04_Resources is maintained OpenWiki output. Restore explicit reviewed "
            "paths outside it instead of discarding wiki content."
        ),
    }
}


def install_hook(path, command):
    data = json.loads(path.read_text()) if path.exists() else {}
    hooks = data.setdefault("hooks", {})
    groups = hooks.setdefault("PreToolUse", [])
    if not isinstance(groups, list):
        raise SystemExit(f"{path}: hooks.PreToolUse must be a list")

    hook = {"command": command, "timeout": 10, "type": "command"}
    for group in groups:
        items = group.get("hooks", []) if isinstance(group, dict) else []
        for item in items:
            installed = item.get("command", "") if isinstance(item, dict) else ""
            if installed.endswith(f"/bin/{GUARD_NAME}"):
                if item == hook and group.get("matcher") == "Bash":
                    return
                item.clear()
                item.update(hook)
                group["matcher"] = "Bash"
                break
        else:
            continue
        break
    else:
        groups.append({"hooks": [hook], "matcher": "Bash"})

    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    with os.fdopen(fd, "w") as tmp:
        json.dump(data, tmp, indent=2)
        tmp.write("\n")
    os.replace(tmp_name, path)


def command_text(tool_input):
    command = tool_input.get("command", tool_input.get("cmd", ""))
    if isinstance(command, list):
        return " ".join(str(part) for part in command)
    return command if isinstance(command, str) else ""


def protects_openwiki_output(payload):
    try:
        Path(payload.get("cwd", "")).resolve().relative_to(VAULT.resolve())
    except (OSError, ValueError):
        return False

    command = command_text(payload.get("tool_input", {}))
    if not re.search(r"\bgit\b.*\brestore\b", command, re.DOTALL):
        return False
    return "04_Resources" in command or bool(
        re.search(r"\brestore\b[^\n]*\s(?:\.|['\"]?:/['\"]?)(?:\s|$)", command)
    )


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--install":
        install_hook(Path(sys.argv[2]), sys.argv[0])
        return

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        print(json.dumps(DENIAL))
        return
    if protects_openwiki_output(payload):
        print(json.dumps(DENIAL))


if __name__ == "__main__":
    main()
