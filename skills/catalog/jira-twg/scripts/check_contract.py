#!/usr/bin/env python3
"""Check local TWG Jira help contracts without making Jira requests."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys


COMMANDS = (
    ("root", ("twg", "--help")),
    ("jira", ("twg", "jira", "--help")),
    ("version", ("twg", "--version")),
    *(
        (name, ("twg", "help", "describe", f"jira workitem {name}"))
        for name in ("get", "query", "search", "create", "update", "transition")
    ),
)
GET_PATHS = (
    "data.key",
    "data.summary",
    "data.status.name",
    "data.assignee.displayName",
    "data.url",
    "data.items.data.key",
    "data.items.data.summary",
    "data.items.data.status.name",
    "data.items.data.assignee.displayName",
    "data.items.data.url",
)
LIST_PATHS = (
    "data.issues.key",
    "data.issues.summary",
    "data.issues.status",
    "data.issues.url",
    "data.issues.updated",
)
SPECS = {
    "get": {
        "args": {"id": {"vari": True}},
        "opts": {"--fields": {"arg": "<fields>"}},
        "presets": {"compact": GET_PATHS},
    },
    "query": {
        "args": {"jql": {}},
        "opts": {
            "--jql": {"arg": "<jql>"},
            "--limit": {"arg": "<limit>", "short": "-n"},
        },
        "presets": {"compact": LIST_PATHS, "rows": LIST_PATHS},
    },
    "search": {
        "args": {"text": {"req": True, "vari": True}},
        "opts": {
            "--fields": {"arg": "<fields>"},
            "--limit": {"arg": "<limit>", "short": "-n"},
        },
        "presets": {"compact": LIST_PATHS, "rows": LIST_PATHS},
    },
    "create": {
        "opts": {
            "--yes": {"short": "-y", "no_arg": True},
            "--space": {"arg": "<space>"},
            "--type": {"arg": "<type>"},
            "--summary": {"arg": "<summary>"},
        }
    },
    "update": {
        "opts": {
            "--id": {"arg": "<id>", "req": True},
            "--status": {"arg": "<status>"},
        }
    },
    "transition": {
        "opts": {
            "--id": {"arg": "<id>", "req": True},
            "--transition-id": {"arg": "<transitionId>"},
        }
    },
}


def run_command(command, timeout):
    return subprocess.run(
        list(command),
        capture_output=True,
        check=False,
        shell=False,
        text=True,
        timeout=timeout,
    )


def add(findings, check, message):
    findings.append({"check": check, "message": message})


def check_members(command, kind, raw, expected, findings):
    key = "name" if kind == "args" else "long"
    if not isinstance(raw, list) or any(
        not isinstance(item, dict) or not isinstance(item.get(key), str) for item in raw
    ):
        add(findings, f"{command}.{kind}-shape", f"Inspect malformed {command} help.")
        return
    entries = {item[key]: item for item in raw}
    for name, attributes in expected.items():
        entry = entries.get(name)
        label = name.removeprefix("--")
        if entry is None:
            add(
                findings,
                f"{command}.{kind}.{label}",
                f"Update jira-twg: {command} lost {name}.",
            )
            continue
        for attribute, value in attributes.items():
            matches = (
                "arg" not in entry
                if attribute == "no_arg"
                else entry.get(attribute) == value
            )
            if not matches:
                add(
                    findings,
                    f"{command}.{kind}.{label}.{attribute}",
                    f"Update jira-twg: {command} {name} changed.",
                )


def check_contract(timeout, runner=run_command):
    outputs: dict[str, str] = {}
    findings: list[dict[str, str]] = []
    for label, command in COMMANDS:
        try:
            result = runner(command, timeout)
        except FileNotFoundError:
            add(findings, "twg.executable", "Expose TWG before using jira-twg.")
            break
        except subprocess.TimeoutExpired:
            add(findings, f"{label}.timeout", f"Inspect TWG: {label} help timed out.")
            continue
        except (OSError, UnicodeError, subprocess.SubprocessError):
            add(
                findings,
                f"{label}.execution",
                f"Inspect TWG: {label} help failed to run.",
            )
            continue
        if result.returncode:
            add(findings, f"{label}.exit", f"Inspect TWG: {label} help failed.")
        else:
            outputs[label] = result.stdout

    root = outputs.get("root")
    if root is not None:
        for flag in ("--agent-fields", "--output", "--output-summary", "--select"):
            if not re.search(
                rf"(?m)^\s*(?:-[A-Za-z],\s*)?{re.escape(flag)}(?:\s|$)", root
            ):
                add(
                    findings,
                    f"root.option.{flag[2:]}",
                    f"Update TWG or jira-twg: help lost {flag}.",
                )
    jira = outputs.get("jira")
    if jira is not None and "twg jira workitem create --space PROJ" not in jira:
        add(
            findings, "jira.create-example", "Update writes.md: help lost --space PROJ."
        )

    version = outputs.get("version", "").strip() or None
    if version is not None and not re.fullmatch(
        r"\d+(?:\.\d+){1,3}(?:[-+][A-Za-z0-9.-]+)?", version
    ):
        add(findings, "version.format", "Inspect TWG: malformed version output.")
        version = None

    for command, spec in SPECS.items():
        raw = outputs.get(command)
        if raw is None:
            continue
        try:
            payload = json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            payload = None
        if not isinstance(payload, dict):
            add(
                findings,
                f"{command}.help-json",
                f"Inspect TWG: malformed {command} help.",
            )
            continue
        if payload.get("cmd") != f"twg jira workitem {command}":
            add(
                findings,
                f"{command}.command",
                f"Update jira-twg: {command} path changed.",
            )
        for kind in ("args", "opts"):
            if kind in spec:
                check_members(command, kind, payload.get(kind), spec[kind], findings)
        output = payload.get("output")
        presets = (
            output.get("agentFieldPresets", {}) if isinstance(output, dict) else {}
        )
        for preset, expected in spec.get("presets", {}).items():
            actual = presets.get(preset) if isinstance(presets, dict) else None
            if (
                not isinstance(actual, list)
                or len(actual) != len(expected)
                or set(actual) != set(expected)
            ):
                add(
                    findings,
                    f"{command}.preset.{preset}",
                    f"Update SKILL.md: {command} @{preset} changed.",
                )

    unique = sorted({(item["check"], item["message"]) for item in findings})
    normalized = [{"check": check, "message": message} for check, message in unique]
    return {"findings": normalized, "ok": not normalized, "version": version}


def positive_timeout(value):
    timeout = float(value)
    if timeout <= 0:
        raise argparse.ArgumentTypeError("timeout must be greater than zero")
    return timeout


def main(argv=None, runner=run_command):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--timeout", type=positive_timeout, default=5.0)
    args = parser.parse_args(argv)
    report = check_contract(args.timeout, runner)
    if args.json:
        print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    elif report["ok"]:
        print(f"jira-twg contract OK (TWG {report['version']})")
    else:
        for finding in report["findings"]:
            print(f"{finding['check']}: {finding['message']}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
