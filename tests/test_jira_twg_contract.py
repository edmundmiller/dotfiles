from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/catalog/jira-twg/scripts/check_contract.py"
SKILL = SCRIPT.parents[1] / "SKILL.md"
WRITES = SCRIPT.parents[1] / "references/writes.md"
SPEC = importlib.util.spec_from_file_location("jira_twg_contract", SCRIPT)
assert SPEC and SPEC.loader
CONTRACT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CONTRACT
SPEC.loader.exec_module(CONTRACT)

COMMANDS = [
    ("twg", "--help"),
    ("twg", "jira", "--help"),
    ("twg", "--version"),
    *(
        ("twg", "help", "describe", f"jira workitem {name}")
        for name in ("get", "query", "search", "create", "update", "transition")
    ),
]
GET = [
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
]
ROWS = [
    "data.issues.key",
    "data.issues.summary",
    "data.issues.status",
    "data.issues.url",
    "data.issues.updated",
]


def described(name, args=None, opts=None, paths=None):
    value = {"cmd": f"twg jira workitem {name}", "opts": opts or []}
    if args is not None:
        value["args"] = args
    if paths:
        value["output"] = {"agentFieldPresets": {"compact": paths, "rows": paths}}
    return json.dumps(value)


def responses():
    values = {
        COMMANDS[
            0
        ]: "-o, --output <format>\n--output-summary [level]\n--agent-fields <paths>\n--select <paths>\n",
        COMMANDS[1]: "twg jira workitem create --space PROJ --type Task\n",
        COMMANDS[2]: "1.2.7\n",
        COMMANDS[3]: described(
            "get",
            [{"name": "id", "vari": True}],
            [{"long": "--fields", "arg": "<fields>"}],
            GET,
        ),
        COMMANDS[4]: described(
            "query",
            [{"name": "jql"}],
            [
                {"long": "--jql", "arg": "<jql>"},
                {"long": "--limit", "arg": "<limit>", "short": "-n"},
            ],
            ROWS,
        ),
        COMMANDS[5]: described(
            "search",
            [{"name": "text", "req": True, "vari": True}],
            [
                {"long": "--fields", "arg": "<fields>"},
                {"long": "--limit", "arg": "<limit>", "short": "-n"},
            ],
            ROWS,
        ),
        COMMANDS[6]: described(
            "create",
            opts=[
                {"long": "--yes", "short": "-y"},
                {"long": "--space", "arg": "<space>"},
                {"long": "--type", "arg": "<type>"},
                {"long": "--summary", "arg": "<summary>"},
            ],
        ),
        COMMANDS[7]: described(
            "update",
            opts=[
                {"long": "--id", "arg": "<id>", "req": True},
                {"long": "--status", "arg": "<status>"},
            ],
        ),
        COMMANDS[8]: described(
            "transition",
            opts=[
                {"long": "--id", "arg": "<id>", "req": True},
                {"long": "--transition-id", "arg": "<transitionId>"},
            ],
        ),
    }
    return values


class Runner:
    def __init__(self, values, failure=None):
        self.values, self.failure, self.calls = values, failure, []

    def __call__(self, command, timeout):
        key = tuple(command)
        self.calls.append((key, timeout))
        if key == self.failure:
            return subprocess.CompletedProcess(key, 7, "", "authorization=secret")
        return subprocess.CompletedProcess(key, 0, self.values[key], "")


class JiraTwgContractTests(unittest.TestCase):
    def test_skill_forbids_retry_loops_and_requires_safe_substitution(self):
        skill = SKILL.read_text()
        writes = WRITES.read_text()
        self.assertIn("Never repeat an identical command.", skill)
        self.assertIn("Never retry an ambiguous write.", writes)
        self.assertIn("shell-quote every substituted value", writes)
        self.assertNotIn("retry once", writes)

    def test_valid_contract_uses_only_local_help_with_timeout_and_no_shell(self):
        runner = Runner(responses())
        self.assertTrue(CONTRACT.check_contract(1.25, runner)["ok"])
        self.assertEqual(runner.calls, [(command, 1.25) for command in COMMANDS])
        completed = subprocess.CompletedProcess([], 0, "", "")
        with mock.patch.object(
            CONTRACT.subprocess, "run", return_value=completed
        ) as run:
            CONTRACT.run_command(COMMANDS[0], 2)
        self.assertFalse(run.call_args.kwargs["shell"])
        self.assertEqual(run.call_args.kwargs["timeout"], 2)

    def test_drifted_contract_reports_flags_options_and_presets(self):
        values = responses()
        values[COMMANDS[0]] = values[COMMANDS[0]].replace("--select <paths>\n", "")
        create = json.loads(values[COMMANDS[6]])
        create["opts"] = create["opts"][1:]
        values[COMMANDS[6]] = json.dumps(create)
        query = json.loads(values[COMMANDS[4]])
        query["output"]["agentFieldPresets"]["rows"].append("data.issues.description")
        values[COMMANDS[4]] = json.dumps(query)
        checks = [
            item["check"]
            for item in CONTRACT.check_contract(1, Runner(values))["findings"]
        ]
        self.assertEqual(
            checks, ["create.opts.yes", "query.preset.rows", "root.option.select"]
        )

    def test_malformed_and_failed_help_are_safe_findings(self):
        values = responses()
        values[COMMANDS[5]] = "{bad-json"
        report = CONTRACT.check_contract(1, Runner(values, COMMANDS[4]))
        encoded = json.dumps(report)
        self.assertEqual(
            [item["check"] for item in report["findings"]],
            ["query.exit", "search.help-json"],
        )
        self.assertNotIn("authorization=secret", encoded)

    def test_findings_are_sorted_and_repeatable(self):
        values = responses()
        values[COMMANDS[0]] = "--output\n"
        values[COMMANDS[1]] = "Jira help\n"
        first = CONTRACT.check_contract(1, Runner(values))["findings"]
        second = CONTRACT.check_contract(1, Runner(dict(reversed(values.items()))))[
            "findings"
        ]
        self.assertEqual(
            first, sorted(first, key=lambda item: (item["check"], item["message"]))
        )
        self.assertEqual(first, second)

    def test_json_output_is_structured_and_nonzero_on_findings(self):
        values = responses()
        values[COMMANDS[0]] = values[COMMANDS[0]].replace(
            "--agent-fields <paths>\n", ""
        )
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            status = CONTRACT.main(["--json", "--timeout", "2"], Runner(values))
        payload = json.loads(stdout.getvalue())
        self.assertEqual(status, 1)
        self.assertFalse(payload["ok"])
        self.assertEqual(payload["findings"][0]["check"], "root.option.agent-fields")
        self.assertEqual(stderr.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
