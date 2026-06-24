#!/usr/bin/env bash
# Validate Pi settings source JSONC against the local JSON schema.
# Run: bash modules/agents/pi/test-settings-json.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
settings="$repo_root/config/pi/settings.jsonc"
schema="$repo_root/config/pi/settings-schema.json"
python_bin="${PI_SETTINGS_JSON_PYTHON:-python3}"

"$python_bin" - "$settings" "$schema" <<'PY'
import json
import pathlib
import sys

try:
    import jsonschema
except ModuleNotFoundError as exc:
    raise SystemExit(
        "FAIL: missing python module 'jsonschema'; run through the prek hook or set PI_SETTINGS_JSON_PYTHON"
    ) from exc


def strip_jsonc(text: str) -> str:
    out = []
    in_string = False
    escaped = False
    i = 0

    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        if char == '"':
            in_string = True
            out.append(char)
            i += 1
            continue

        if char == "/" and nxt == "/":
            out.extend("  ")
            i += 2
            while i < len(text) and text[i] not in "\r\n":
                out.append(" ")
                i += 1
            continue

        if char == "/" and nxt == "*":
            out.extend("  ")
            i += 2
            while i < len(text):
                if text[i] == "*" and i + 1 < len(text) and text[i + 1] == "/":
                    out.extend("  ")
                    i += 2
                    break
                out.append("\n" if text[i] in "\r\n" else " ")
                i += 1
            continue

        out.append(char)
        i += 1

    return "".join(out)


def remove_trailing_commas(text: str) -> str:
    out = []
    in_string = False
    escaped = False
    i = 0

    while i < len(text):
        char = text[i]

        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        if char == '"':
            in_string = True
            out.append(char)
            i += 1
            continue

        if char == ",":
            j = i + 1
            while j < len(text) and text[j].isspace():
                j += 1
            if j < len(text) and text[j] in "]}":
                i += 1
                continue

        out.append(char)
        i += 1

    return "".join(out)


settings_path = pathlib.Path(sys.argv[1])
schema_path = pathlib.Path(sys.argv[2])

settings = json.loads(remove_trailing_commas(strip_jsonc(settings_path.read_text(encoding="utf-8"))))
schema = json.loads(schema_path.read_text(encoding="utf-8"))
jsonschema.Draft7Validator.check_schema(schema)
jsonschema.validate(settings, schema)


def package_source(pkg):
    if isinstance(pkg, str):
        return pkg
    if isinstance(pkg, dict):
        return pkg.get("source", "")
    return ""


package_sources = {package_source(pkg) for pkg in settings.get("packages", [])}
if settings.get("theme") == "terminal" and "npm:pi-terminal-theme" not in package_sources:
    raise SystemExit(
        "FAIL: theme 'terminal' requires package 'npm:pi-terminal-theme' in config/pi/settings.jsonc"
    )

print("PASS: config/pi/settings.jsonc matches config/pi/settings-schema.json")
PY
