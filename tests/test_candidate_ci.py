"""Candidate admission through the real CLI and Git remotes; GitHub is simulated."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/candidate_ci.py"
URL = "https://github.com/edmundmiller/dotfiles.git"


class CandidateCiTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.remote = self.root / "remote.git"
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.root / "hooks"))
        (self.repo / "scripts").mkdir()
        for name in ("candidate_ci.py", "validation.py"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        (self.repo / "file").write_text("base\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "base")
        self.base = self.git("rev-parse", "HEAD")
        subprocess.run(["git", "init", "--quiet", "--bare", str(self.remote)], check=True)
        self.git("remote", "add", "origin", URL)
        # Keep the production remote identity; redirect its transport to a local bare repo.
        self.git("config", f"url.{self.remote}.insteadOf", URL)
        self.git("push", "origin", "HEAD:refs/heads/main")
        (self.repo / "file").write_text("candidate\n")
        self.git("commit", "--quiet", "-am", "candidate")
        self.sha = self.git("rev-parse", "HEAD")
        self.branch = f"candidate/{self.base}/{self.sha}"
        self.state = {
            "run": {
                "id": 17, "run_attempt": 2, "head_sha": self.sha,
                "head_branch": self.branch, "event": "push",
                "path": ".github/workflows/ci.yml", "status": "completed",
                "conclusion": "success", "html_url": "https://example.invalid/run/17",
            },
            "jobs": [
                {"name": name, "conclusion": "success"}
                for name in ("Flake Check (Linux)", "Check Formatting")
            ],
        }
        self.save()
        tools = self.root / "tools"
        tools.mkdir()
        gh = tools / "gh"
        gh.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "from urllib.parse import urlparse, parse_qs\n"
            "args = sys.argv[1:]\n"
            "assert args[:3] == ['api', '--hostname', 'github.com'], args\n"
            "assert '--method' not in args, args\n"
            "state = json.loads(Path(os.environ['CANDIDATE_FIXTURE']).read_text())\n"
            "endpoint = args[3]\n"
            "if '/attempts/' in endpoint:\n"
            "    assert endpoint.endswith('/17/attempts/2/jobs?per_page=100'), endpoint\n"
            "    result = [{'jobs': state['jobs']}]\n"
            "    if state.get('rerun'):\n"
            "        state['run'].update(status='in_progress', conclusion=None, run_attempt=3)\n"
            "        Path(os.environ['CANDIDATE_FIXTURE']).write_text(json.dumps(state))\n"
            "else:\n"
            "    query = parse_qs(urlparse(endpoint).query)\n"
            "    assert query['event'] == ['push'] and query['per_page'] == ['1'], query\n"
            "    assert query['branch'] == [os.environ['CANDIDATE_BRANCH']], query\n"
            "    assert query['head_sha'] == [os.environ['CANDIDATE_SHA']], query\n"
            "    result = {'workflow_runs': [state['run']] if state['run'] else []}\n"
            "print(json.dumps(result))\n"
        )
        gh.chmod(0o755)
        self.env = os.environ | {
            "PATH": f"{tools}{os.pathsep}{os.environ['PATH']}",
            "CANDIDATE_FIXTURE": str(self.root / "github.json"),
            "CANDIDATE_BRANCH": self.branch,
            "CANDIDATE_SHA": self.sha,
            "GH_HOST": "unrelated.invalid",
        }

    def git(self, *args):
        return subprocess.check_output(
            ["git", *args], cwd=self.repo, text=True, stderr=subprocess.PIPE
        ).strip()

    def save(self):
        (self.root / "github.json").write_text(json.dumps(self.state))

    def cli(self, command, **environment):
        args = [] if command == "base" else ["--base", self.base, "--sha", self.sha]
        return subprocess.run(
            [sys.executable, str(SCRIPT), command, *args],
            cwd=self.repo, env=self.env | environment, text=True,
            capture_output=True, timeout=10,
        )

    def remote_main(self):
        return self.git("ls-remote", "origin", "refs/heads/main").split()[0]

    def test_submit_then_land_exact_passing_sha_without_pr_or_history_rewrite(self):
        result = self.cli("submit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_main(), self.base)
        self.assertEqual(
            self.git("ls-remote", "origin", f"refs/heads/{self.branch}").split()[0],
            self.sha,
        )
        result = self.cli("land")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_main(), self.sha)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.sha)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_bypassed_push_is_published_but_not_reported_as_compliant(self):
        self.assertEqual(self.cli("submit").returncode, 0)
        hook = self.remote / "hooks" / "post-receive"
        hook.write_text("#!/bin/sh\necho 'Bypassed rule violations for main' >&2\n")
        hook.chmod(0o755)
        result = self.cli("land")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Ref was published with a policy bypass", result.stderr)
        self.assertEqual(self.remote_main(), self.sha)

    def test_missing_wrong_or_unsuccessful_ci_never_advances_main(self):
        self.assertEqual(self.cli("submit").returncode, 0)
        original = json.loads(json.dumps(self.state))
        cases = [
            ("status", "in_progress"), ("conclusion", "failure"),
            ("conclusion", "cancelled"), ("head_sha", self.base),
            ("head_branch", "main"), ("event", "pull_request"),
            ("path", ".github/workflows/other.yml"), ("run_attempt", None),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                self.state = json.loads(json.dumps(original))
                self.state["run"][field] = value
                self.save()
                self.assertNotEqual(self.cli("land").returncode, 0)
                self.assertEqual(self.remote_main(), self.base)
        for state in (original | {"run": None}, original | {"rerun": True}):
            self.state = state
            self.save()
            self.assertNotEqual(self.cli("land").returncode, 0)
            self.assertEqual(self.remote_main(), self.base)
        for jobs in ([], original["jobs"][:1], [
            {"name": "Flake Check (Linux)", "conclusion": "skipped"},
            original["jobs"][1],
        ]):
            with self.subTest(jobs=jobs):
                self.state = original | {"jobs": jobs}
                self.save()
                self.assertNotEqual(self.cli("land").returncode, 0)
                self.assertEqual(self.remote_main(), self.base)

    def test_competing_main_push_is_not_overwritten(self):
        self.assertEqual(self.cli("submit").returncode, 0)
        # An independent commit shares the base but is not in this candidate.
        tree = self.git("rev-parse", "HEAD^{tree}")
        other = self.git("commit-tree", tree, "-p", self.base, "-m", "other task")
        self.git("push", "origin", f"{other}:refs/heads/other")
        hooks = self.root / "hooks"
        hooks.mkdir()
        hook = hooks / "pre-push"
        hook.write_text(
            f"#!/bin/sh\ngit --git-dir='{self.remote}' update-ref refs/heads/main {other}\n"
        )
        hook.chmod(0o755)
        result = self.cli("land")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.remote_main(), other)
        # The same obsolete candidate must also fail before another push is attempted.
        hook.unlink()
        self.assertNotEqual(self.cli("land").returncode, 0)
        self.assertNotEqual(self.cli("submit").returncode, 0)
        self.assertEqual(self.remote_main(), other)

    def test_candidate_base_is_explicit_and_rejects_stale_or_mismatched_refs(self):
        self.git("fetch", "origin", "main:refs/remotes/origin/main")
        environment = {
            "GITHUB_EVENT_NAME": "push", "GITHUB_REF_NAME": self.branch,
            "GITHUB_SHA": self.sha, "VALIDATION_BASE": "0" * 40,
        }
        result = self.cli("base", **environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.base)
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        planner = workflow.split("      - id: plan\n", 1)[1].split("\n  checks:", 1)[0]
        command = textwrap.dedent(planner.split("        run: |\n", 1)[1])
        output = self.root / "outputs"
        result = subprocess.run(
            ["bash", "-euc", command], cwd=self.repo,
            env=self.env | environment | {"GITHUB_OUTPUT": str(output)},
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text().splitlines(), [f"base={self.base}", "herdr_vm=false"])
        for change in (
            {"GITHUB_SHA": self.base},
            {"GITHUB_REF_NAME": f"candidate/{self.sha}/{self.sha}"},
            {"GITHUB_REF_NAME": "candidate/not-a-sha"},
        ):
            with self.subTest(change=change):
                self.assertNotEqual(self.cli("base", **(environment | change)).returncode, 0)
        result = self.cli("base", GITHUB_EVENT_NAME="push", GITHUB_REF_NAME="main",
                          VALIDATION_BASE=self.base)
        self.assertEqual(result.stdout.strip(), self.base)

    def test_dirty_worktree_or_wrong_candidate_cannot_be_submitted(self):
        (self.repo / "untracked").write_text("uncommitted\n")
        self.assertNotEqual(self.cli("submit").returncode, 0)
        (self.repo / "untracked").unlink()
        self.git("checkout", "--quiet", self.base)
        self.assertNotEqual(self.cli("submit").returncode, 0)
        self.assertEqual(self.remote_main(), self.base)


if __name__ == "__main__":
    unittest.main()
