"""Exercise workspace isolation with real jj and an isolated Rex server."""

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
SCRIPT = ROOT / "config/rex/jj-workspace.py"
REX = shutil.which("rex")


@unittest.skipUnless(REX and shutil.which("jj"), "requires installed Rex and jj")
class RexWorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="rex-jj-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.endpoint = f"unix://{self.root}/server.sock"
        for name, command in {
            "rex": [REX, "--autostart=false", "-S", self.endpoint],
            "agent-run": [sys.executable, str(ROOT / "bin/agent-run")],
            "rex-jj": [sys.executable, str(SCRIPT)],
        }.items():
            wrapper = self.bin / name
            wrapper.write_text("#!/bin/sh\nexec " + shlex.join(command) + ' "$@"\n')
            wrapper.chmod(0o755)
        self.env = os.environ | {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "JJ_CONFIG": str(self.root / "jj.toml"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "AGENT": "/bin/pwd",
        }
        # Apply the module's executable substitution to this test installation.
        config = self.root / "init.lua"
        config.write_text(
            (ROOT / "config/rex/init.lua")
            .read_text()
            .replace("@rexJj@", str(self.bin / "rex-jj"))
        )
        (self.root / "jj.toml").write_text(
            '[user]\nname = "Test"\nemail = "test@example.com"\n'
            '[signing]\nbehavior = "drop"\n'
        )
        self.run_ok("jj", "git", "init", "--colocate", str(self.repo))
        (self.repo / "value.txt").write_text("base\n")
        self.run_ok("jj", "commit", "-m", "base")
        self.base = self.run_ok(
            "jj", "log", "-r", "@-", "--no-graph", "-T", "commit_id"
        ).strip()
        self.run_ok("jj", "bookmark", "create", "main", "-r", "@-")
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
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if self.run_cmd("rex", "whoami", "--json").returncode == 0:
                break
            time.sleep(0.1)
        else:
            self.fail((self.root / "server.log").read_text())

    def stop_server(self):
        if self.server.poll() is None:
            self.run_cmd("rex", "server", "stop")
            self.server.wait(timeout=10)

    def run_cmd(self, *command, cwd=None):
        return subprocess.run(
            command,
            cwd=cwd or self.repo,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=30,
        )

    def run_ok(self, *command, cwd=None):
        result = self.run_cmd(*command, cwd=cwd)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def create_task(self, task="task-one", repo=None, base="main"):
        return json.loads(
            self.run_ok(
                sys.executable,
                str(SCRIPT),
                "new",
                task,
                "--repo",
                str(repo or self.repo),
                "--base",
                base,
            )
        )

    def test_create_isolates_changes_and_reuses_or_reopens_session(self):
        agent = self.root / "selected agent"
        agent.write_text("#!/bin/sh\nexec /bin/pwd\n")
        agent.chmod(0o755)
        self.env["AGENT"] = "../selected agent"
        (self.repo / "value.txt").write_text("primary-only\n")
        primary = self.run_ok("jj", "log", "-r", "@", "--no-graph", "-T", "change_id")
        state = self.create_task()
        child = Path(state["workspace"])
        self.assertEqual((child / "value.txt").read_text(), "base\n")
        self.assertEqual(
            self.run_ok(
                "jj", "log", "-r", "@-", "--no-graph", "-T", "commit_id", cwd=child
            ).strip(),
            self.base,
        )
        self.assertEqual(
            self.run_ok(
                "jj",
                "log",
                "-r",
                "task-one",
                "--no-graph",
                "-T",
                "change_id",
                cwd=child,
            ),
            self.run_ok(
                "jj", "log", "-r", "@", "--no-graph", "-T", "change_id", cwd=child
            ),
        )
        self.assertEqual(
            primary,
            self.run_ok("jj", "log", "-r", "@", "--no-graph", "-T", "change_id"),
        )
        receipt = json.loads(Path(state["receiptPath"]).read_text())
        self.assertEqual(receipt["workspaceRoot"], str(child))
        self.assertEqual(receipt["runtime"], "../selected agent")
        view = json.loads(
            self.run_ok("rex", "session", "inspect", state["session_id"], "--json")
        )
        self.assertEqual(view["label"], "task-one")
        self.assertEqual(len(view["windows"]), 2)
        block = state["initial_windows"][1]["block_ids"][0]
        self.run_ok("rex", "wait", "-s", state["session_id"], block, "--for", "15s")
        output = self.run_ok(
            "rex",
            "capture",
            "-s",
            state["session_id"],
            "-b",
            block,
            "--trim",
            "--unwrap",
        )
        self.assertIn(str(child), output)
        self.run_ok(
            "rex", "session", "rename", state["session_id"], "human-renamed-task"
        )
        reopened = json.loads(
            self.run_ok(sys.executable, str(SCRIPT), "open", str(child))
        )
        self.assertTrue(reopened["reused"])
        self.assertEqual(reopened["session_id"], state["session_id"])
        self.run_ok("rex", "kill", state["session_id"])
        reopened = json.loads(
            self.run_ok(sys.executable, str(SCRIPT), "open", str(child))
        )
        self.assertFalse(reopened["reused"])
        self.assertNotEqual(reopened["session_id"], state["session_id"])
        self.assertEqual(reopened["receiptPath"], state["receiptPath"])
        # Creation from a child uses the same repository namespace and explicit stack base.
        (child / "value.txt").write_text("stack-parent\n")
        self.run_ok("jj", "status", cwd=child)
        second = self.create_task("task-two", child, "task-one")
        self.assertEqual(Path(second["workspace"]).parent, child.parent)
        self.assertEqual(
            (Path(second["workspace"]) / "value.txt").read_text(), "stack-parent\n"
        )

    def test_rejects_collisions_invalid_input_and_git_only_worktrees(self):
        self.create_task()
        for arguments, message in [
            (["new", "task-one", "--base", "main"], "bookmark already exists"),
            (["new", "../escape", "--base", "main"], "task slug"),
            (["new", "no-agent", "--agent", "1"], "Set AGENT"),
            (["new", "bad-base", "--base", "missing-bookmark"], "doesn't exist"),
        ]:
            with self.subTest(arguments=arguments):
                result = self.run_cmd(sys.executable, str(SCRIPT), *arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
        worktree = self.root / "git-only"
        self.run_ok("git", "worktree", "add", "--detach", str(worktree), "HEAD")
        result = self.run_cmd(
            sys.executable, str(SCRIPT), "new", "git-task", "--repo", str(worktree)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Git-only", result.stderr)
        self.assertFalse((worktree / ".jj").exists())
        sessions = json.loads(self.run_ok("rex", "ls", "--json"))["sessions"]
        self.assertEqual(len(sessions), 1)
        # A stopped server must not cause the newly created checkout to be deleted.
        self.stop_server()
        result = self.run_cmd(
            sys.executable, str(SCRIPT), "new", "recoverable", "--base", "main"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rex-jj open", result.stderr)
        child = Path(
            self.run_ok("jj", "workspace", "root", "--name", "recoverable").strip()
        )
        self.assertEqual((child / "value.txt").read_text(), "base\n")

    def test_non_colocated_review_does_not_read_ancestor_git_checkout(self):
        child = self.repo / "nested"
        help_text = self.run_ok("jj", "workspace", "add", "--help")
        flags = ["--no-colocate"] if "--no-colocate" in help_text else []
        self.run_ok(
            "jj",
            "workspace",
            "add",
            *flags,
            "--name",
            "nested",
            "-r",
            "main",
            str(child),
        )
        (self.repo / "value.txt").write_text("parent-must-not-appear\n")
        (child / "value.txt").write_text("child-review-content\n")
        output = self.run_ok(sys.executable, str(SCRIPT), "review", str(child))
        self.assertIn("+child-review-content", output)
        self.assertNotIn("parent-must-not-appear", output)
        session = json.loads(
            self.run_ok(
                "rex",
                "new",
                "review-action",
                "-c",
                str(child),
                "--json",
                "--",
                "/bin/sleep",
                "60",
            )
        )
        block = session["initial_windows"][0]["block_ids"][0]
        window = json.loads(
            self.run_ok(
                "rex",
                "do",
                "-s",
                session["session_id"],
                "-b",
                block,
                "jj_workspace_review",
                "--json",
            )
        )
        review = window["block_ids"][0]
        self.run_ok("rex", "wait", "-s", session["session_id"], review, "--for", "15s")
        output = self.run_ok(
            "rex",
            "capture",
            "-s",
            session["session_id"],
            "-b",
            review,
            "--trim",
            "--unwrap",
        )
        self.assertIn("+child-review-content", output)
        self.assertNotIn("parent-must-not-appear", output)


if __name__ == "__main__":
    unittest.main()
