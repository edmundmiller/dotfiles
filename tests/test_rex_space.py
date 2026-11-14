"""Exercise the space CLI against a real isolated Rex server with a deterministic Pi stand-in."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "config/rex/space.lua"
REX = shutil.which("rex")


@unittest.skipUnless(REX, "requires Rex")
class RexSpaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="rex-space-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.cwd = self.root / "project with spaces"
        self.cwd.mkdir()
        self.space = self.root / "state with spaces"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.intercom = self.root / "intercom/index.ts"
        self.intercom.parent.mkdir()
        self.intercom.write_text("// Pi stand-in does not execute extensions.\n")
        self.endpoint = f"unix://{self.root}/server.sock"
        config = self.root / "init.lua"
        config.write_text("")
        wrapper = self.bin / "rex"
        wrapper.write_text(
            "#!/bin/sh\nexec "
            + shlex.join([REX, "--autostart=false", "-S", self.endpoint])
            + ' "$@"\n'
        )
        wrapper.chmod(0o755)
        # This fixture is a process, not a model. Verify orchestration separately
        # from the paid, nondeterministic model smoke test described in the README.
        pi = self.bin / "pi"
        pi.write_text(
            f"#!{sys.executable}\n"
            + """
import json, os, pathlib, sys, time
args = sys.argv[1:]
session = pathlib.Path(args[args.index("--session") + 1])
identity = {"scope": os.environ.get("PI_INTERCOM_SCOPE_ID"), "id": os.environ.get("PI_INTERCOM_STABLE_ID")}
if "-p" not in args:
    with session.open("a") as stream:
        stream.write(json.dumps({"args": args, **identity}) + "\\n")
    print("head-ready", flush=True)
    time.sleep(120)
else:
    session.write_text(json.dumps({"args": args, **identity}) + "\\n")
    prompt = args[-1].split("Task:\\n", 1)[1]
    print("worker-started", flush=True)
    if prompt == "hold":
        time.sleep(120)
    if prompt == "fail":
        print("specific worker failure", file=sys.stderr)
        sys.exit(7)
    print("report: " + prompt + " cwd=" + str(pathlib.Path.cwd()))
"""
        )
        pi.chmod(0o755)
        self.env = os.environ | {"PATH": f"{self.bin}:{os.environ['PATH']}"}
        self.log = (self.root / "server.log").open("w")
        self.addCleanup(self.log.close)
        self.server = subprocess.Popen(
            [
                REX,
                "server",
                "run",
                "--listen",
                self.endpoint,
                "--state-dir",
                str(self.root / "server-state"),
                "--config",
                str(config),
            ],
            env=self.env,
            stdout=self.log,
            stderr=self.log,
        )
        self.addCleanup(self.stop_server)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if self.rex("whoami", "--json", check=False).returncode == 0:
                break
            time.sleep(0.1)
        else:
            self.fail((self.root / "server.log").read_text())
        self.created = self.cli(
            "new",
            "example",
            "--cwd",
            str(self.cwd),
            "--goal",
            "test goal",
            "--intercom",
            str(self.intercom),
        )
        self.wait_for(lambda: (self.space / "head.jsonl").exists())

    def stop_server(self):
        if self.server.poll() is None:
            self.rex("server", "stop", check=False)
            self.server.wait(timeout=10)

    def rex(self, *args, check=True):
        return subprocess.run(
            [REX, "--autostart=false", "-S", self.endpoint, *args],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
            check=check,
        )

    def call(self, *args):
        # Keep test scenarios readable while passing native Rex Lua JSON arguments.
        values = {"space": str(self.space)}
        positional = []
        arguments = iter(args)
        for value in arguments:
            if value.startswith("--"):
                values[value[2:]] = next(arguments)
            else:
                positional.append(value)
        values["command"] = positional[0]
        if len(positional) > 1:
            values["name" if positional[0] == "new" else "task"] = positional[1]
        return subprocess.run(
            [REX, "do", str(SCRIPT), "--args", json.dumps(values)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
        )

    def cli(self, *args):
        result = self.call(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def wait_for(self, predicate):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail("Rex space condition did not become true")

    def test_visible_parallel_workers_results_and_live_head_reuse(self):
        head = self.created["head_block"]
        first = self.cli("delegate", "first", "--prompt", "hold")
        second = self.cli(
            "delegate", "second", "--prompt", "quoted 'task'; $(do-not-run)"
        )
        self.assertNotEqual(first["block_id"], second["block_id"])
        windows = json.loads(
            self.rex("session", "inspect", self.created["session_id"], "--json").stdout
        )
        focused = [
            window["focused_block_id"]
            for window in windows["windows"]
            if window["window_id"] == windows["active_window_id"]
        ]
        self.assertEqual(
            focused, [head], "background workers must not steal head focus"
        )
        self.assertEqual(self.cli("open")["head_block"], head)
        self.assertTrue(self.cli("open")["reused"])
        self.wait_for(lambda: (self.space / "tasks/second/result.json").exists())
        tasks = self.cli("status")["tasks"]
        self.assertEqual([task["status"] for task in tasks], ["running", "done"])
        output = Path(tasks[1]["output_path"]).read_text()
        self.assertIn("quoted 'task'; $(do-not-run)", output)
        self.assertIn(f"cwd={self.cwd}", output)
        self.assertEqual(self.call("wait", "--timeout", "0").returncode, 2)
        self.assertEqual(
            self.call("delegate", "second", "--prompt", "overwrite").returncode, 1
        )
        self.rex("block", "close", "-s", self.created["session_id"], first["block_id"])
        interrupted = self.call("wait", "--timeout", "0")
        self.assertEqual(interrupted.returncode, 1, interrupted.stderr)
        self.assertEqual(
            json.loads(interrupted.stdout)["tasks"][0]["status"], "interrupted"
        )

    def test_failure_is_durable_and_wait_is_not_success(self):
        self.cli("delegate", "successful", "--prompt", "success")
        success = self.call("wait", "--timeout", "10")
        self.assertEqual(success.returncode, 0, success.stderr)
        self.assertIn(
            "report: success",
            Path(json.loads(success.stdout)["tasks"][0]["output_path"]).read_text(),
        )
        self.cli("delegate", "broken", "--prompt", "fail")
        result = self.call("wait", "--timeout", "10")
        self.assertEqual(result.returncode, 1, result.stderr)
        task = json.loads(result.stdout)["tasks"][0]
        self.assertEqual((task["status"], task["exit_code"]), ("failed", 7))
        self.assertIn("specific worker failure", Path(task["output_path"]).read_text())
        self.rex("kill", self.created["session_id"])
        self.assertEqual(self.cli("status")["tasks"][0]["exit_code"], 7)

    def test_resume_after_closed_head_and_lost_session(self):
        transcript = self.space / "head.jsonl"
        self.rex(
            "block",
            "close",
            "-s",
            self.created["session_id"],
            self.created["head_block"],
        )
        reopened = self.cli("open")
        self.assertEqual(reopened["session_id"], self.created["session_id"])
        self.assertNotEqual(reopened["head_block"], self.created["head_block"])
        self.wait_for(lambda: len(transcript.read_text().splitlines()) == 2)
        self.rex("kill", self.created["session_id"])
        restarted = self.cli("open")
        self.assertNotEqual(restarted["session_id"], self.created["session_id"])
        self.wait_for(lambda: len(transcript.read_text().splitlines()) == 3)
        launches = [json.loads(line) for line in transcript.read_text().splitlines()]
        self.assertEqual(
            {launch["id"] for launch in launches}, {self.created["intercom"]["head_id"]}
        )
        self.assertEqual(
            {launch["scope"] for launch in launches},
            {self.created["intercom"]["scope"]},
        )
        args = launches[-1]["args"]
        self.assertNotIn("test goal", args, "resume must not replay the initial goal")

    def test_four_worker_limit_and_path_traversal_rejection(self):
        for name in ("one", "two", "three", "four"):
            self.cli("delegate", name, "--prompt", "hold")
        rejected = self.call("delegate", "five", "--prompt", "hold")
        self.assertEqual(rejected.returncode, 1)
        self.assertIn("four workers", rejected.stderr)
        self.assertFalse((self.space / "tasks/five").exists())
        self.assertEqual(
            self.call("delegate", "../../escape", "--prompt", "hold").returncode, 1
        )
        self.assertEqual(self.space.stat().st_mode & 0o777, 0o700)

    @unittest.skipUnless(sys.platform == "darwin", "requires macOS power state")
    def test_sleep_causing_clamshell_rejects_launch_without_partial_state(self):
        power_probe = self.bin / "ioreg"
        for lid_closed, causes_sleep in ((False, True), (True, False), (True, True)):
            power = (
                f'"AppleClamshellState" = {"Yes" if lid_closed else "No"}\n'
                f'"AppleClamshellCausesSleep" = {"Yes" if causes_sleep else "No"}\n'
            )
            power_probe.write_text(f"#!/bin/sh\ncat <<'PLIST'\n{power}PLIST\n")
            power_probe.chmod(0o755)
            if not (lid_closed and causes_sleep):
                self.assertTrue(self.cli("open")["reused"])
                continue
            before = self.rex(
                "block", "ls", "-s", self.created["session_id"], "--json"
            ).stdout
            rejected = self.call("delegate", "sleeping", "--prompt", "hold")
            self.assertEqual(rejected.returncode, 1, rejected.stdout)
            self.assertIn("lid-closed sleep", rejected.stderr)
            self.assertFalse((self.space / "tasks/sleeping").exists())
            self.assertEqual(self.call("open").returncode, 1)
            self.assertEqual(
                self.rex(
                    "block", "ls", "-s", self.created["session_id"], "--json"
                ).stdout,
                before,
            )
            missing = self.root / "sleeping space"
            rejected = self.call(
                "--space",
                str(missing),
                "new",
                "sleeping",
                "--cwd",
                str(self.cwd),
                "--goal",
                "nothing",
                "--intercom",
                str(self.intercom),
            )
            self.assertEqual(rejected.returncode, 1, rejected.stdout)
            self.assertIn("lid-closed sleep", rejected.stderr)
            self.assertFalse(missing.exists())
            self.assertEqual(self.cli("status")["tasks"], [])

    def test_intercom_scopes_identities_and_cooperative_wait(self):
        self.cli("delegate", "question", "--prompt", "hold")
        worker_session = self.space / "tasks/question/session.jsonl"
        self.wait_for(worker_session.exists)
        head = json.loads((self.space / "head.jsonl").read_text().splitlines()[0])
        worker = json.loads(worker_session.read_text())
        self.assertEqual(worker["scope"], head["scope"])
        self.assertNotEqual(worker["id"], head["id"])
        self.assertIn(
            head["id"], worker["args"][-1], "worker must know the exact head address"
        )
        self.assertIn(str(self.intercom), worker["args"])
        self.assertIn(str(self.intercom), head["args"])
        started = time.monotonic()
        yielded = self.call("wait", "--timeout", "60")
        self.assertEqual(yielded.returncode, 2, yielded.stderr)
        self.assertLess(
            time.monotonic() - started,
            9,
            "head must not block incoming asks for a minute",
        )
        configured = self.cli("enable-intercom", "--intercom", str(self.intercom))
        self.assertEqual(configured["intercom"]["head_id"], head["id"])
        other = self.root / "second space"
        created = self.cli(
            "--space",
            str(other),
            "new",
            "other",
            "--cwd",
            str(self.cwd),
            "--goal",
            "other goal",
            "--intercom",
            str(self.intercom),
        )
        self.assertNotEqual(created["intercom"]["scope"], head["scope"])
        missing = self.root / "missing package space"
        rejected = self.call(
            "--space",
            str(missing),
            "new",
            "missing",
            "--cwd",
            str(self.cwd),
            "--goal",
            "nothing",
            "--intercom",
            str(self.root / "absent/index.ts"),
        )
        self.assertEqual(rejected.returncode, 1)
        self.assertIn("npm install --prefix", rejected.stderr)
        self.assertFalse(
            missing.exists(), "missing intercom must not leave a partial space"
        )


if __name__ == "__main__":
    unittest.main()
