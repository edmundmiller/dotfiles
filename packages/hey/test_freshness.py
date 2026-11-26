"""Freshness behavior against real disposable repositories, never host tasks."""

from contextlib import redirect_stderr
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("freshness", SOURCE / "freshness.py")
freshness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(freshness)


class FreshnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.remote = self.home / "remote"
        self.remote.mkdir()
        self.env = os.environ | {
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_AUTHOR_NAME": "Fixture",
            "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture",
            "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        }
        self.git(self.remote, "init", "-q", "-b", "main")
        (self.remote / "packages/hey").mkdir(parents=True)
        (self.remote / "packages/hey/default.nix").touch()
        (self.remote / "flake.nix").write_text("{}\n")
        self.commit(self.remote, "base")
        self.base = self.git(self.remote, "rev-parse", "HEAD")
        self.root = self.home / "checkout with spaces"
        self.git(self.home, "clone", "-q", str(self.remote), str(self.root))
        self.cache = self.root / ".git/hey-freshness"
        self.commit(self.remote, "upstream one")
        self.commit(self.remote, "upstream two")

    def git(self, root, *args):
        return subprocess.check_output(
            ["git", "-C", str(root), "-c", "core.hooksPath=/dev/null", *args],
            env=self.env,
            stderr=subprocess.PIPE,
            text=True,
        ).strip()

    def commit(self, root, message):
        self.git(root, "add", ".")
        self.git(root, "commit", "-q", "--allow-empty", "--no-gpg-sign", "-m", message)

    def run_check(self, root=None):
        return subprocess.run(
            [sys.executable, str(SOURCE / "freshness.py")],
            cwd=root or self.root,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=5,
            check=True,
        )

    def test_clean_main_warns_with_explicit_update_and_never_pulls(self):
        result = self.run_check()
        self.assertEqual(result.stdout, "")
        self.assertIn("2 commit(s) behind origin/main (branch main)", result.stderr)
        self.assertIn("merge --ff-only origin/main", result.stderr)
        self.assertIn(f"git -C '{self.root}' fetch origin", result.stderr)
        self.assertEqual(self.git(self.root, "rev-parse", "HEAD"), self.base)
        self.assertEqual(self.git(self.root, "status", "--porcelain"), "")
        self.git(self.root, "merge", "--ff-only", "origin/main")
        self.assertEqual(self.run_check().stderr, "")

    def test_dirty_diverged_detached_and_feature_work_stays_untouched(self):
        for branch in ("main", "feature", "detached"):
            with self.subTest(branch=branch):
                self.git(self.root, "checkout", "--detach", self.base)
                if branch != "detached":
                    self.git(self.root, "checkout", "-B", branch)
                self.commit(self.root, f"local {branch}")
                local = self.git(self.root, "rev-parse", "HEAD")
                (self.root / "untracked").write_text("keep me")
                before = self.git(self.root, "status", "--porcelain")
                result = self.run_check()
                self.assertIn("2 commit(s) behind", result.stderr)
                self.assertIn("1 commit(s) ahead of origin/main", result.stderr)
                self.assertIn("dirty checkout", result.stderr)
                self.assertIn("detached HEAD" if branch == "detached" else f"branch {branch}", result.stderr)
                self.assertNotIn("to update explicitly", result.stderr)
                self.assertEqual(self.git(self.root, "rev-parse", "HEAD"), local)
                self.assertEqual(self.git(self.root, "status", "--porcelain"), before)
                self.assertEqual((self.root / "untracked").read_text(), "keep me")
                (self.root / "untracked").unlink()

    def test_ahead_only_is_not_behind_and_foreign_projects_are_ignored(self):
        self.git(self.root, "fetch", "origin")
        self.git(self.root, "merge", "--ff-only", "origin/main")
        self.commit(self.root, "unpublished")
        self.assertEqual(self.run_check().stderr, "")
        shutil.rmtree(self.root / "packages")
        self.cache.unlink()
        self.assertEqual(self.run_check().stderr, "")
        self.assertFalse(self.cache.exists())

    def test_cache_is_shared_with_worktrees_and_refreshes_after_expiry(self):
        self.run_check()
        self.commit(self.remote, "upstream three")
        worktree = self.home / "worktree"
        self.git(self.root, "worktree", "add", "--detach", str(worktree), self.base)
        self.assertIn("2 commit(s) behind", self.run_check(worktree).stderr)
        self.assertFalse((worktree / "hey-freshness").exists())
        self.cache.write_text('{"attempt": 0}')
        self.assertIn("3 commit(s) behind", self.run_check(worktree).stderr)

    def test_offline_timeout_is_bounded_cached_and_does_not_block_task(self):
        self.run_check()
        sleeper = self.home / "slow-upload-pack"
        terminated = self.home / "terminated"
        sleeper.write_text(
            f"#!{sys.executable}\nimport pathlib, signal, sys, time\n"
            "def stop(signum, frame):\n"
            f"    pathlib.Path({str(terminated)!r}).write_text('terminated')\n"
            "    sys.exit(0)\n"
            "signal.signal(signal.SIGTERM, stop)\n"
            "time.sleep(30)\n"
        )
        sleeper.chmod(0o755)
        self.git(self.root, "config", "remote.origin.uploadpack", str(sleeper))
        self.cache.unlink()
        started = time.monotonic()
        result = self.run_check()
        self.assertLess(time.monotonic() - started, 2.5)
        self.assertIn("2 commit(s) behind cached origin/main; refresh failed/offline", result.stderr)
        started = time.monotonic()
        self.assertIn("cached origin/main", self.run_check().stderr)
        self.assertLess(time.monotonic() - started, 0.8)
        self.assertEqual(self.git(self.root, "rev-parse", "HEAD"), self.base)
        self.assertEqual(terminated.read_text(), "terminated")
        self.git(self.root, "config", "--unset", "remote.origin.uploadpack")
        self.git(self.root, "fetch", "origin")
        # An uncooperative transport must also stop within the cleanup budget.
        survived = self.home / "survived-timeout"
        sleeper.write_text(
            f"#!{sys.executable}\nimport pathlib, signal, time\n"
            "def ignore(signum, frame):\n"
            "    time.sleep(0.4)\n"
            f"    pathlib.Path({str(survived)!r}).touch()\n"
            "signal.signal(signal.SIGTERM, ignore)\n"
            "time.sleep(30)\n"
        )
        self.git(self.root, "config", "remote.origin.uploadpack", str(sleeper))
        self.cache.unlink()
        started = time.monotonic()
        self.run_check()
        self.assertLess(time.monotonic() - started, 2.5)
        time.sleep(0.5)
        self.assertFalse(survived.exists(), "transport survived forced cleanup")
        self.git(self.root, "config", "--unset", "remote.origin.uploadpack")
        self.git(self.root, "fetch", "origin")

    def test_advisory_fetch_skips_hooks_and_leaves_no_lock_for_next_fetch(self):
        hook = self.root / ".git/hooks/reference-transaction"
        marker = self.home / "hook-ran"
        hook.write_text(
            f"#!{sys.executable}\nimport pathlib, sys, time\n"
            "if sys.argv[1] == 'prepared':\n"
            f"    pathlib.Path({str(marker)!r}).touch()\n"
            "    time.sleep(30)\n"
        )
        hook.chmod(0o755)
        result = self.run_check()
        hook.unlink()
        # A timed-out hook used to strand origin/main.lock and break this fetch.
        self.git(self.root, "fetch", "origin")
        self.assertFalse(marker.exists())
        self.assertIn("2 commit(s) behind origin/main", result.stderr)
        self.assertEqual(self.git(self.root, "rev-parse", "HEAD"), self.base)

    def test_cancelling_fetch_stops_transport_and_allows_the_next_fetch(self):
        ready = self.home / "transport-ready"
        stopped = self.home / "transport-stopped"
        transport = self.home / "upload-pack"
        transport.write_text(
            f"#!{sys.executable}\nimport os, pathlib, signal, sys, time\n"
            "def stop(signum, frame):\n"
            f"    pathlib.Path({str(stopped)!r}).touch()\n"
            "    sys.exit(0)\n"
            "signal.signal(signal.SIGTERM, stop)\n"
            f"pathlib.Path({str(ready)!r}).write_text(str(os.getpgrp()))\n"
            "time.sleep(30)\n"
        )
        transport.chmod(0o755)

        def interactive_signals():
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            signal.signal(signal.SIGTERM, signal.SIG_DFL)

        for signum in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=signum):
                self.git(self.root, "config", "remote.origin.uploadpack", str(transport))
                self.cache.unlink(missing_ok=True)
                ready.unlink(missing_ok=True)
                stopped.unlink(missing_ok=True)
                group = None
                with subprocess.Popen(
                    [sys.executable, "-I", str(SOURCE / "freshness.py")],
                    cwd=self.root, env=self.env, start_new_session=True,
                    preexec_fn=interactive_signals, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                ) as child:
                    try:
                        deadline = time.monotonic() + 3
                        while time.monotonic() < deadline:
                            if ready.exists() and ready.read_text():
                                group = int(ready.read_text())
                                break
                            time.sleep(0.01)
                        self.assertIsNotNone(group, "fetch transport did not start")
                        started = time.monotonic()
                        os.killpg(child.pid, signum)
                        output, errors = child.communicate(timeout=2.5)
                        self.assertLess(time.monotonic() - started, 2.5)
                        self.assertTrue(stopped.exists(), "cancelled fetch transport was left running")
                        self.assertEqual(child.returncode, 128 + signum)
                        self.assertEqual(output, b"")
                        self.assertEqual(errors, b"")
                    finally:
                        if group is not None:
                            try:
                                os.killpg(group, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                        if child.poll() is None:
                            os.killpg(child.pid, signal.SIGKILL)
                        child.communicate()
                self.git(self.root, "config", "--unset", "remote.origin.uploadpack")
                self.git(self.root, "fetch", "origin")

    def test_missing_remote_history_and_opt_out(self):
        self.git(self.root, "remote", "remove", "origin")
        self.assertIn("cannot compare with origin/main", self.run_check().stderr)
        self.cache.unlink()
        self.env["HEY_FRESHNESS"] = "0"
        self.assertEqual(self.run_check().stderr, "")
        self.assertFalse(self.cache.exists())

    def test_unknown_shallow_ancestry_is_not_reported_as_divergence(self):
        self.git(self.root, "fetch", "origin")
        (self.root / ".git/shallow").write_text(self.base + "\n")
        self.git(self.root, "checkout", "--orphan", "unrelated")
        self.commit(self.root, "other root")
        result = self.run_check()
        self.assertIn("no known common ancestor", result.stderr)
        self.assertNotIn("ahead of origin/main", result.stderr)
        self.assertNotIn("to update explicitly", result.stderr)

    def test_active_revision_is_separate_from_checkout_and_result_link(self):
        self.git(self.root, "fetch", "origin")
        self.git(self.root, "merge", "--ff-only", "origin/main")
        active = self.home / "active"
        active.mkdir()
        metadata = active / "darwin-version.json"
        metadata.write_text(json.dumps({"configurationRevision": self.base}))
        built = self.home / "built"
        built.mkdir()
        (built / "darwin-version.json").write_text(json.dumps({"configurationRevision": self.git(self.root, "rev-parse", "HEAD")}))
        (self.root / "result").symlink_to(built)
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            with patch.dict(os.environ, self.env), patch.object(freshness, "CURRENT_SYSTEM", active):
                output = io.StringIO()
                with redirect_stderr(output):
                    freshness.check()
                self.assertIn(f"active system {self.base[:12]} is 2 commit(s) behind this checkout", output.getvalue())
                metadata.write_text(json.dumps({"configurationRevision": self.git(self.root, "rev-parse", "HEAD")}))
                output = io.StringIO()
                with redirect_stderr(output):
                    freshness.check()
                self.assertEqual(output.getvalue(), "")
                metadata.unlink()
                nixos_version = active / "sw/bin/nixos-version"
                nixos_version.parent.mkdir(parents=True)
                nixos_version.write_text(
                    f"#!{sys.executable}\n"
                    f"print('dotfiles={self.base};agents-workspace={'a' * 40}')\n"
                )
                nixos_version.chmod(0o755)
                output = io.StringIO()
                with redirect_stderr(output):
                    freshness.check()
                self.assertIn(f"active system {self.base[:12]} is 2 commit(s) behind this checkout", output.getvalue())
                for revision in (
                    f"dotfiles={self.base}-dirty;agents-workspace={'a' * 40}",
                    f"dotfiles={self.base};agents-workspace=invalid",
                ):
                    with self.subTest(revision=revision):
                        nixos_version.write_text(f"#!{sys.executable}\nprint({revision!r})\n")
                        output = io.StringIO()
                        with redirect_stderr(output):
                            freshness.check()
                        self.assertEqual(output.getvalue(), "")
        finally:
            os.chdir(previous)

    def test_active_warning_survives_missing_or_unrelated_remote_history(self):
        self.git(self.root, "fetch", "origin")
        self.git(self.root, "merge", "--ff-only", "origin/main")
        self.git(self.root, "remote", "remove", "origin")
        active = self.home / "active"
        active.mkdir()
        (active / "darwin-version.json").write_text(json.dumps({"configurationRevision": self.base}))
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            with patch.dict(os.environ, self.env), patch.object(freshness, "CURRENT_SYSTEM", active):
                for remote in ("missing", "unrelated"):
                    with self.subTest(remote=remote):
                        if remote == "unrelated":
                            # Keep HEAD and its known active ancestor unchanged.
                            self.git(self.remote, "checkout", "--orphan", "other-root")
                            self.commit(self.remote, "unrelated")
                            self.git(self.root, "fetch", str(self.remote), "other-root:refs/remotes/origin/main")
                        output = io.StringIO()
                        with redirect_stderr(output):
                            freshness.check()
                        self.assertIn(
                            "cannot compare" if remote == "missing" else "no known common ancestor",
                            output.getvalue(),
                        )
                        self.assertIn(f"active system {self.base[:12]} is 2 commit(s) behind this checkout", output.getvalue())
        finally:
            os.chdir(previous)

    def test_locked_or_unavailable_cache_preserves_source_and_active_warnings(self):
        self.git(self.root, "fetch", "origin")
        remote = self.git(self.root, "rev-parse", "origin/main")
        self.git(self.root, "merge", "--ff-only", "origin/main~1")
        self.commit(self.remote, "not fetched while cache unavailable")
        active = self.home / "active"
        active.mkdir()
        (active / "darwin-version.json").write_text(json.dumps({"configurationRevision": self.base}))
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            with patch.dict(os.environ, self.env), patch.object(freshness, "CURRENT_SYSTEM", active):
                with self.cache.open("a+") as held:
                    fcntl.flock(held, fcntl.LOCK_EX)
                    for mode in ("locked", "unavailable"):
                        with self.subTest(cache=mode):
                            if mode == "unavailable":
                                self.cache.unlink()
                                self.cache.mkdir()
                            output = io.StringIO()
                            started = time.monotonic()
                            with redirect_stderr(output):
                                freshness.check()
                            self.assertLess(time.monotonic() - started, 0.8)
                            self.assertIn("1 commit(s) behind cached origin/main", output.getvalue())
                            self.assertIn(f"active system {self.base[:12]} is 1 commit(s) behind this checkout", output.getvalue())
                            self.assertEqual(self.git(self.root, "rev-parse", "origin/main"), remote)
        finally:
            os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
