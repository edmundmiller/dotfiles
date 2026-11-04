#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Test generated permission checks with isolated external service doubles."""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import unittest


ARGS = None


def extract_function(text, name):
    matches = list(
        re.finditer(r"(?m)^([ \t]*)" + re.escape(name) + r"\(\) \{\s*$", text)
    )
    if len(matches) != 1:
        raise AssertionError(f"Expected one {name} function, found {len(matches)}")
    match = matches[0]
    closing = re.search(
        r"(?m)^" + re.escape(match[1]) + r"\}[ \t]*$", text[match.end() :]
    )
    if closing is None:
        raise AssertionError(f"Missing closing brace for {name}")
    return text[match.start() : match.end() + closing.end()] + "\n", match[1]


def extract_app_check(text):
    function, indent = extract_function(text, "ensureAppManagement")
    start = text.index(function.rstrip("\n"))
    after = start + len(function.rstrip("\n"))
    condition = re.search(
        r"(?m)^" + re.escape(indent) + r"if ! ensureAppManagement; then[ \t]*$",
        text[after:],
    )
    if condition is None:
        raise AssertionError("Missing actual App Management condition")
    body_start = after + condition.end()
    closing = re.search(r"(?m)^" + re.escape(indent) + r"fi[ \t]*$", text[body_start:])
    if closing is None:
        raise AssertionError("Missing outer App Management condition end")
    return text[start : body_start + closing.end()] + "\n"


FAKE_SERVICE = r"""#!PYTHON
import json,os,sys
from pathlib import Path
name=Path(sys.argv[0]).name
with open(os.environ["TRACE"],"a") as stream:
 stream.write(json.dumps({"command":name,"args":sys.argv[1:]})+"\n")
if name=="launchctl":
 print(os.environ["MANAGER"])
 raise SystemExit(0)
if name=="dscl":
 if "-read" in sys.argv:
  print("NFSHomeDirectory: /var/empty")
  raise SystemExit(0)
 raise SystemExit(int(os.environ["DENY_USER"]))
if name=="touch": raise SystemExit(int(os.environ["DENY_APP"]))
if name=="tccutil": raise SystemExit(0)
raise SystemExit(127)
"""


class FailClosedActivationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = Path(ARGS.raw_checks).read_text()
        cls.guarded = Path(ARGS.checks_source).read_text()
        cls.raw_user = Path(ARGS.raw_user_checks).read_text()
        cls.guarded_user = Path(ARGS.user_checks_source).read_text()

    def run_check(self, kind, *, guarded, denied, manager="Aqua"):
        if kind == "user":
            text = self.guarded_user if guarded else self.raw_user
        else:
            text = self.guarded if guarded else self.raw
        with tempfile.TemporaryDirectory(prefix="fail-closed-tcc-") as temporary:
            root = Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            for command in ["touch", "dscl", "launchctl", "tccutil"]:
                program = fake_bin / command
                program.write_text(FAKE_SERVICE.replace("PYTHON", sys.executable, 1))
                program.chmod(0o755)
            apps = root / "apps"
            (apps / "Fixture.app").mkdir(parents=True)
            if kind == "app":
                code = extract_app_check(text)
                target = r"/Applications/Nix\ Apps/*.app"
                self.assertEqual(code.count(target), 1)
                code = code.replace(target, shlex.quote(str(apps)) + "/*.app")
            else:
                function, _ = extract_function(text, "ensurePerms")
                code = function + "ensurePerms fixture create\n"
            after = root / "subsequent-work"
            trace = root / "calls.jsonl"
            environment = {
                "PATH": str(fake_bin),
                "LC_ALL": "C",
                "TRACE": str(trace),
                "MANAGER": manager,
                "DENY_APP": str(int(denied and kind == "app")),
                "DENY_USER": str(int(denied and kind == "user")),
                "AFTER": str(after),
            }
            result = subprocess.run(
                [
                    ARGS.bash,
                    "--noprofile",
                    "--norc",
                    "-e",
                    "-c",
                    code + 'printf continued > "$AFTER"\n',
                ],
                env=environment,
                capture_output=True,
                text=True,
                timeout=10,
            )
            calls = (
                [json.loads(line) for line in trace.read_text().splitlines()]
                if trace.exists()
                else []
            )
            return result, calls, after.exists()

    def test_generated_checks_source_equals_configured_text(self):
        self.assertEqual(
            Path(ARGS.checks_source).read_bytes(),
            Path(ARGS.expected_checks).read_bytes(),
        )
        self.assertNotIn("tccutil", self.guarded)
        self.assertIn("ensureAppManagement()", self.guarded)
        self.assertEqual("ensurePerms()" in self.guarded, "ensurePerms()" in self.raw)
        self.assertIn("ensurePerms()", self.guarded_user)
        self.assertNotIn("tccutil", self.guarded_user)

    def test_generated_full_script_source_equals_configured_text(self):
        actual = Path(ARGS.script_source).read_bytes()
        self.assertEqual(actual, Path(ARGS.expected_script).read_bytes())
        self.assertNotIn(b"tccutil", actual)
        self.assertIn(b"refuses automatic TCC reset", actual)

    def test_unguarded_failures_reach_real_external_reset_double(self):
        for kind, service in [
            ("app", "SystemPolicyAppBundles"),
            ("user", "SystemPolicySysAdminFiles"),
        ]:
            with self.subTest(kind=kind):
                result, calls, after = self.run_check(kind, guarded=False, denied=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(after)
                resets = [call for call in calls if call["command"] == "tccutil"]
                self.assertEqual(
                    [call["args"] for call in resets], [["reset", service]]
                )
                self.assertEqual(
                    sum(
                        call["command"] == ("touch" if kind == "app" else "dscl")
                        and (kind == "app" or "-change" in call["args"])
                        for call in calls
                    ),
                    2,
                )

    def test_guarded_aqua_failures_abort_without_reset_or_retry(self):
        for kind, service in [
            ("app", "SystemPolicyAppBundles"),
            ("user", "SystemPolicySysAdminFiles"),
        ]:
            with self.subTest(kind=kind):
                result, calls, after = self.run_check(kind, guarded=True, denied=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(after)
                self.assertIn(
                    "refuses automatic TCC reset for " + service, result.stderr
                )
                self.assertFalse(any(call["command"] == "tccutil" for call in calls))
                probes = [
                    call
                    for call in calls
                    if call["command"] == ("touch" if kind == "app" else "dscl")
                    and (kind == "app" or "-change" in call["args"])
                ]
                self.assertEqual(len(probes), 1)

    def test_success_reaches_subsequent_work_without_reset(self):
        for kind in ["app", "user"]:
            with self.subTest(kind=kind):
                result, calls, after = self.run_check(kind, guarded=True, denied=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(after)
                self.assertFalse(any(call["command"] == "tccutil" for call in calls))
                self.assertTrue(
                    any(
                        call["command"] == ("touch" if kind == "app" else "dscl")
                        for call in calls
                    )
                )

    def test_non_aqua_failure_preserves_upstream_denial_without_reset(self):
        for kind in ["app", "user"]:
            with self.subTest(kind=kind):
                result, calls, after = self.run_check(
                    kind, guarded=True, denied=True, manager="System"
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(after)
                self.assertIn("SSH", result.stderr)
                self.assertFalse(any(call["command"] == "tccutil" for call in calls))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in [
        "raw-checks",
        "checks-source",
        "raw-user-checks",
        "user-checks-source",
        "expected-checks",
        "script-source",
        "expected-script",
        "bash",
    ]:
        parser.add_argument("--" + name, required=True)
    ARGS = parser.parse_args()
    unittest.main(argv=[sys.argv[0]])
