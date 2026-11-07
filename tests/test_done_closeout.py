import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from tests.done_bend import SKILL, binary


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


class DoneCloseoutTest(unittest.TestCase):
    def init_repo(self, root: Path) -> tuple[Path, Path]:
        remote = root / "remote.git"
        repo = root / "repo"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True)
        subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
        git(repo, "config", "user.name", "Done Test")
        git(repo, "config", "user.email", "done@example.invalid")
        (repo / "base.txt").write_text("base\n")
        git(repo, "add", "base.txt")
        git(repo, "commit", "-m", "base")
        git(repo, "remote", "add", "origin", str(remote))
        git(repo, "push", "-u", "origin", "main")
        subprocess.run(
            ["git", "-C", str(remote), "symbolic-ref", "HEAD", "refs/heads/main"],
            check=True,
        )
        git(repo, "remote", "set-head", "origin", "-a")
        return repo, remote

    def run_closeout(self, *args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [binary("closeout"), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
        )

    def run_publish_clean(
        self,
        *args: str,
        cwd: Path,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [binary("publish-clean"), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            env=env,
        )

    def source_state(self, repo: Path) -> dict[str, object]:
        return {
            "head": git(repo, "rev-parse", "HEAD"),
            "branch": git(repo, "branch", "--show-current"),
            "status": git(repo, "status", "--porcelain=v1", "--untracked-files=all"),
            "cached": git(repo, "diff", "--cached", "--binary", "--no-ext-diff"),
            "unstaged": git(repo, "diff", "--binary", "--no-ext-diff"),
            "base": (repo / "base.txt").read_bytes(),
            "untracked": (repo / "untracked.txt").read_bytes(),
        }

    def create_task_revision(self, repo: Path, root: Path) -> tuple[Path, str]:
        task = root / "task"
        git(repo, "worktree", "add", "-b", "task", str(task), "main")
        (task / "task.txt").write_text("task\n")
        git(task, "add", "task.txt")
        git(task, "commit", "-m", "task")
        return task, git(task, "rev-parse", "HEAD")

    def test_snapshot_is_structured_secret_safe_and_repeatable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, _ = self.init_repo(Path(tmp))
            secret = "not-for-output"
            (repo / "untracked.txt").write_text(secret)

            first = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            second = subprocess.run(
                [
                    "bend",
                    str(SKILL / "scripts/closeout.bend"),
                    "--",
                    "snapshot",
                    "--repo",
                    str(repo),
                ],
                cwd=repo,
                capture_output=True,
                text=True,
            )

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            payload = json.loads(first.stdout)
            self.assertEqual(payload["schemaVersion"], 1)
            self.assertEqual(payload["backend"], "git")
            self.assertEqual(payload["destination"]["defaultBranch"], "main")
            self.assertEqual(payload["destination"]["remote"], "origin")
            self.assertFalse(payload["workingCopy"]["clean"])
            self.assertEqual(first.stdout, second.stdout)
            self.assertNotIn(secret, first.stdout)
            self.assertEqual(
                payload["workingCopy"]["untracked"][0]["path"], "untracked.txt"
            )

    def test_snapshot_falls_back_to_git_without_a_usable_jj(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            (repo / "base.txt").write_text("staged\n")
            git(repo, "add", "base.txt")
            (repo / "base.txt").write_text("unstaged\n")
            (repo / "untracked.txt").write_text("keep me\n")
            before = self.source_state(repo)
            tools = root / "bin"
            tools.mkdir()
            for command in ("git", "sh", "bash", "jq", "sha256sum", "readlink"):
                (tools / command).symlink_to(shutil.which(command))

            for jj_installed in (False, True):
                with self.subTest(jj_installed=jj_installed):
                    if jj_installed:
                        jj = tools / "jj"
                        jj.write_text("#!/bin/sh\nexit 1\n")
                        jj.chmod(0o755)
                    result = subprocess.run(
                        [binary("closeout"), "snapshot", "--repo", str(repo)],
                        cwd=repo,
                        env={**os.environ, "PATH": str(tools)},
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    payload = json.loads(result.stdout)
                    self.assertEqual(payload["backend"], "git")
                    self.assertEqual(payload["schemaVersion"], 1)
                    self.assertEqual(payload["vcs"]["head"], before["head"])
                    self.assertFalse(payload["workingCopy"]["clean"])
                    self.assertEqual(self.source_state(repo), before)
                    self.assertFalse((repo / ".jj").exists())

    def test_snapshot_preserves_binary_files_and_control_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            name = '  control\x01\n" snowman ☃'
            content = b"\xff\x00secret\n"
            (repo / name).write_bytes(content)
            (repo / "symlink").symlink_to("missing-target")
            receipt = root / "receipt.json"
            receipt.write_text(json.dumps({"schemaVersion": 2, "status": "blocked"}))
            result = self.run_closeout(
                "snapshot", "--repo", str(repo), "--receipt", str(receipt), cwd=repo
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            hashes = {
                entry["path"]: entry["sha256"]
                for entry in payload["workingCopy"]["untracked"]
            }
            self.assertEqual(hashes[name], hashlib.sha256(content).hexdigest())
            self.assertEqual(
                hashes["symlink"], hashlib.sha256(b"missing-target").hexdigest()
            )
            snapshot = root / "snapshot.json"
            snapshot.write_text(json.dumps(payload, sort_keys=True))
            preserved = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot), cwd=repo
            )
            self.assertEqual(preserved.returncode, 0, preserved.stderr)

    def test_verify_preservation_detects_changed_unrelated_dirt(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            (repo / "untracked.txt").write_text("before\n")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            unchanged = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot_path), cwd=repo
            )
            self.assertEqual(unchanged.returncode, 0, unchanged.stderr)

            (repo / "untracked.txt").write_text("after\n")
            changed = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot_path), cwd=repo
            )
            self.assertEqual(changed.returncode, 1)
            self.assertIn("working-copy fingerprint changed", changed.stderr)

    def test_relative_receipt_survives_directory_change(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            receipt = repo / "receipt \n.json"
            receipt.write_text(json.dumps({"schemaVersion": 2, "runId": "source"}))
            snapshot = self.run_closeout(
                "snapshot", "--repo", str(repo), "--receipt", receipt.name, cwd=repo
            )
            self.assertEqual(snapshot.returncode, 0, snapshot.stderr)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)
            self.assertEqual(
                json.loads(snapshot.stdout)["receipt"]["path"], str(receipt)
            )
            (root / receipt.name).write_text("not a receipt")
            preserved = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot_path), cwd=root
            )
            self.assertEqual(preserved.returncode, 0, preserved.stderr)

    def test_snapshot_accepts_untracked_nested_repository(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, _ = self.init_repo(Path(tmp))
            nested = repo / "nested"
            nested.mkdir()
            git(nested, "init", "-b", "main")
            git(
                nested,
                "-c",
                "user.name=Test",
                "-c",
                "user.email=test@example.invalid",
                "commit",
                "--allow-empty",
                "-m",
                "nested",
            )
            result = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            self.assertEqual(result.returncode, 0, result.stderr)
            work = json.loads(result.stdout)["workingCopy"]
            self.assertFalse(work["clean"])
            self.assertEqual(
                work["untracked"],
                [{"path": "nested/", "sha256": hashlib.sha256(b"").hexdigest()}],
            )

    def test_classify_blocks_unrelated_local_default_commits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            base = git(repo, "rev-parse", "HEAD")
            (repo / "task.txt").write_text("task\n")
            git(repo, "add", "task.txt")
            git(repo, "commit", "-m", "task")
            task = git(repo, "rev-parse", "HEAD")
            (repo / "other.txt").write_text("other\n")
            git(repo, "add", "other.txt")
            git(repo, "commit", "-m", "other")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                task,
                "--authority",
                "full",
                cwd=repo,
            )

            self.assertEqual(result.returncode, 1)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "blocked")
            self.assertEqual(len(payload["unrelatedLocalCommits"]), 1)
            self.assertIn("publication authority", payload["blockers"][0])

    def test_malformed_snapshot_is_unknown_not_a_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.json"
            path.write_text("not-json")
            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(path),
                "--task-revision",
                "x",
                cwd=Path(tmp),
            )

            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertIn("cannot read snapshot", result.stderr)
            self.assertNotIn("Traceback", result.stderr)

    def test_classify_accepts_aggregate_patch_equivalent_squash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            base = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "-c", "task")
            (repo / "one.txt").write_text("one\n")
            git(repo, "add", "one.txt")
            git(repo, "commit", "-m", "one")
            one = git(repo, "rev-parse", "HEAD")
            (repo / "two.txt").write_text("two\n")
            git(repo, "add", "two.txt")
            git(repo, "commit", "-m", "two")
            two = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "main")
            git(repo, "merge", "--squash", "task")
            git(repo, "commit", "-m", "squashed task")
            landed = git(repo, "rev-parse", "HEAD")
            git(repo, "push", "origin", "main")
            git(repo, "switch", "task")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                one,
                "--task-revision",
                two,
                "--landed-revision",
                landed,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "ready")
            self.assertEqual(payload["destination"]["defaultBranch"], "main")
            evidence = [
                item["evidence"] for item in json.loads(result.stdout)["taskRevisions"]
            ]
            self.assertEqual(evidence, ["aggregate-patch-equivalent"] * 2)

    def test_local_only_classification_uses_local_default_without_a_remote(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
            git(repo, "config", "user.name", "Done Test")
            git(repo, "config", "user.email", "done@example.invalid")
            (repo / "base.txt").write_text("base\n")
            git(repo, "add", "base.txt")
            git(repo, "commit", "-m", "base")
            base = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "-c", "task")
            (repo / "task.txt").write_text("task\n")
            git(repo, "add", "task.txt")
            git(repo, "commit", "-m", "task")
            task = git(repo, "rev-parse", "HEAD")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                task,
                "--authority",
                "local-only",
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)

    def test_publish_clean_uses_authoritative_default_over_stale_cached_head(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)

            updater = root / "updater"
            git(root, "clone", str(remote), str(updater))
            git(updater, "config", "user.name", "Done Test")
            git(updater, "config", "user.email", "done@example.invalid")
            git(updater, "switch", "-c", "develop")
            (updater / "develop.txt").write_text("develop\n")
            git(updater, "add", "develop.txt")
            git(updater, "commit", "-m", "develop")
            git(updater, "push", "origin", "develop")
            git(remote, "symbolic-ref", "HEAD", "refs/heads/develop")
            self.assertEqual(
                "refs/remotes/origin/main",
                git(repo, "symbolic-ref", "refs/remotes/origin/HEAD"),
            )

            _, task_revision = self.create_task_revision(repo, root)
            (repo / "untracked.txt").write_text("source dirt\n")
            before = self.source_state(repo)
            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual("develop", payload["defaultBranch"])
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                {"base.txt", "develop.txt", "task.txt"},
                set(
                    git(remote, "ls-tree", "-r", "--name-only", "develop").splitlines()
                ),
            )
            self.assertEqual(
                {"base.txt"},
                set(git(remote, "ls-tree", "-r", "--name-only", "main").splitlines()),
            )

    def test_publish_clean_reports_conflicting_paths_without_publishing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            task, _ = self.create_task_revision(repo, root)
            (task / "base.txt").write_text("task edit\n")
            git(task, "commit", "-am", "conflicting task edit")
            revision = git(task, "rev-parse", "HEAD")
            (repo / "base.txt").write_text("published edit\n")
            git(repo, "commit", "-am", "concurrent edit")
            git(repo, "push", "origin", "main")
            remote_before = git(remote, "rev-parse", "main")
            (repo / "untracked.txt").write_text("preserve source dirt\n")
            before = self.source_state(repo)

            result = self.run_publish_clean(
                "--source-repo", str(repo), "--task-revision", revision, cwd=repo
            )

            self.assertNotEqual(result.returncode, 0)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "blocked")
            self.assertIn("base.txt", payload["error"])
            self.assertIn(revision, payload["error"])
            self.assertEqual(git(remote, "rev-parse", "main"), remote_before)
            self.assertEqual(self.source_state(repo), before)

    def test_publish_clean_leaves_dirty_source_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)

            (repo / "base.txt").write_text("staged source work\n")
            git(repo, "add", "base.txt")
            (repo / "base.txt").write_text("unstaged source work\n")
            (repo / "untracked.txt").write_text("untracked source work\n")
            before = self.source_state(repo)

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "published")
            self.assertEqual(payload["defaultBranch"], "main")
            self.assertEqual(payload["taskRevisions"][0]["initialEvidence"], "unlanded")
            self.assertEqual(
                payload["taskRevisions"][0]["evidence"], "patch-equivalent"
            )
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                payload["remoteTip"],
                git(remote, "rev-parse", "refs/heads/main"),
            )
            self.assertEqual("task\n", (root / "task" / "task.txt").read_text())

    def test_publish_clean_retries_one_non_fast_forward(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)
            (repo / "untracked.txt").write_text("source dirt\n")

            updater = root / "updater"
            git(root, "clone", str(remote), str(updater))
            git(updater, "config", "user.name", "Done Test")
            git(updater, "config", "user.email", "done@example.invalid")
            (updater / "competitor.txt").write_text("competitor\n")
            git(updater, "add", "competitor.txt")
            git(updater, "commit", "-m", "competitor")

            real_git = shutil.which("git")
            self.assertIsNotNone(real_git)
            wrapper_dir = root / "bin"
            wrapper_dir.mkdir()
            marker = root / "race.marker"
            wrapper = wrapper_dir / "git"
            wrapper.write_text(
                f"#!{sys.executable}\n"
                "import os\n"
                "from pathlib import Path\n"
                "import subprocess\n\n"
                'real = os.environ["PUBLISH_REAL_GIT"]\n'
                'marker = Path(os.environ["PUBLISH_RACE_MARKER"])\n'
                "args = os.sys.argv[1:]\n"
                "command = args[2:] if args[:1] == ['-C'] else args\n"
                "if command[:1] == ['push'] and not marker.exists():\n"
                '    subprocess.run([real, "-C", os.environ["PUBLISH_RACE_UPDATER"], "push", "origin", "main"], check=True)\n'
                '    marker.write_text("raced\\n")\n'
                "os.execv(real, [real, *os.sys.argv[1:]])\n"
            )
            wrapper.chmod(0o755)
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{wrapper_dir}:{env['PATH']}",
                    "PUBLISH_REAL_GIT": real_git,
                    "PUBLISH_RACE_MARKER": str(marker),
                    "PUBLISH_RACE_UPDATER": str(updater),
                }
            )
            before = self.source_state(repo)

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "published")
            self.assertEqual(payload["attempts"], 2)
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                {"base.txt", "task.txt", "competitor.txt"},
                set(git(remote, "ls-tree", "-r", "--name-only", "main").splitlines()),
            )

    def test_publish_clean_redacts_remote_credentials_on_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)
            git(
                repo,
                "remote",
                "set-url",
                "origin",
                "https://user:secret-token@127.0.0.1:1/repo.git",
            )

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 1)
            self.assertNotIn("secret-token", result.stdout + result.stderr)
            self.assertEqual("blocked", json.loads(result.stdout)["status"])

    def publisher_policy_environment(
        self,
        root: Path,
        remote: Path,
        policy: dict[str, object],
        push_mode: str = "normal",
    ) -> dict[str, str]:
        """Keep actual Git writes local; substitute only hosted policy and transport replies."""
        wrapper_dir = root / "bin"
        wrapper_dir.mkdir()
        (wrapper_dir / "git").write_text(
            f"#!{sys.executable}\n"
            "import os, subprocess, sys\n"
            "from pathlib import Path\n"
            "args = sys.argv[1:]\n"
            "real = os.environ['PUBLISH_REAL_GIT']\n"
            "url = 'https://github.com/example/project.git'\n"
            "command = args[2:] if args[:1] == ['-C'] else args\n"
            "if command[:2] == ['remote', 'get-url']:\n"
            "    print(url); sys.exit(0)\n"
            "args = [os.environ['PUBLISH_REMOTE'] if a == url else a for a in args]\n"
            "if command[:1] != ['push']:\n"
            "    os.execv(real, [real, *args])\n"
            "marker = Path(os.environ['PUBLISH_PUSHES'])\n"
            "marker.write_text(marker.read_text() + 'push\\n' if marker.exists() else 'push\\n')\n"
            "mode = os.environ['PUBLISH_PUSH_MODE']\n"
            "if mode in ('reject', 'policy-reject'):\n"
            "    print('! [rejected] ' + ('non-fast-forward' if mode == 'reject' else 'protected branch hook declined'), file=sys.stderr)\n"
            "    sys.exit(1)\n"
            "code = subprocess.run([real, *args]).returncode\n"
            "if mode == 'bypass':\n"
            "    print('remote: Bypassed rule violations for refs/heads/main:', file=sys.stderr)\n"
            "    print('remote: Required status check gate was bypassed', file=sys.stderr)\n"
            "    print('remote: https://user:secret-token@github.com/example/project?token=query-secret', file=sys.stderr)\n"
            "if mode == 'transport':\n"
            "    print('fatal: connection lost after write', file=sys.stderr); code = 1\n"
            "sys.exit(code)\n"
        )
        (wrapper_dir / "gh").write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "policy = json.loads(os.environ['PUBLISH_POLICY'])\n"
            "endpoint = sys.argv[-1]\n"
            "host = sys.argv[sys.argv.index('--hostname') + 1] if '--hostname' in sys.argv else os.environ.get('GH_HOST', 'github.com')\n"
            "if host != 'github.com': policy = {'rules': [[]], 'protection': 'absent'}\n"
            "if '/rules/branches/' in endpoint: key = 'rules'\n"
            "elif endpoint.endswith('/protection'): key = 'protection'\n"
            "elif '/check-runs?' in endpoint: key = 'checks'\n"
            "elif '/statuses?' in endpoint: key = 'statuses'\n"
            "else: sys.exit(99)\n"
            "value = policy.get(key, {})\n"
            "if value == 'denied':\n"
            "    print('gh: Resource not accessible (HTTP 403)', file=sys.stderr); sys.exit(1)\n"
            "if value == 'absent':\n"
            '    print(\'{"message":"Branch not protected"}\')\n'
            "    print('gh: Branch not protected (HTTP 404)', file=sys.stderr); sys.exit(1)\n"
            "head = endpoint.split('/commits/')[-1].split('/')[0]\n"
            "print(json.dumps(value).replace('$HEAD', head))\n"
        )
        for wrapper in wrapper_dir.iterdir():
            wrapper.chmod(0o755)
        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{wrapper_dir}:{env['PATH']}",
                "GH_HOST": "github.com",
                "PUBLISH_REAL_GIT": str(shutil.which("git")),
                "PUBLISH_REMOTE": str(remote),
                "PUBLISH_POLICY": json.dumps(policy),
                "PUBLISH_PUSHES": str(root / "pushes"),
                "PUBLISH_PUSH_MODE": push_mode,
            }
        )
        return env

    def test_publish_clean_enforces_exact_head_required_gates_before_writing(
        self,
    ) -> None:
        gate = {
            "type": "required_status_checks",
            "parameters": {
                "required_status_checks": [{"context": "gate", "integration_id": 42}]
            },
        }
        passed = {
            "id": 1,
            "name": "gate",
            "head_sha": "$HEAD",
            "app": {"id": 42},
            "status": "completed",
            "conclusion": "success",
        }
        cases = {
            "missing": [],
            "pending": [{**passed, "status": "in_progress", "conclusion": None}],
            "failed": [{**passed, "conclusion": "failure"}],
            "cancelled": [{**passed, "conclusion": "cancelled"}],
            "wrong-head": [{**passed, "head_sha": "0" * 40}],
            "wrong-app": [{**passed, "app": {"id": 7}}],
            "newer-failed": [passed, {**passed, "id": 2, "conclusion": "failure"}],
            "ambiguous-checks": [{**passed, "conclusion": "failure"}, {**passed, "id": 2}],
            "passed": [passed],
        }
        for name, checks in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                before = git(remote, "rev-parse", "main")
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": [[gate]],
                        "protection": "absent",
                        "checks": [{"check_runs": checks}],
                        "statuses": [[]],
                    },
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                payload = json.loads(result.stdout)
                if name == "passed":
                    self.assertEqual(0, result.returncode, payload)
                    self.assertTrue(payload["policy"]["compliant"])
                    self.assertEqual(
                        payload["integratedTip"], payload["policy"]["head"]
                    )
                else:
                    self.assertEqual(1, result.returncode, payload)
                    self.assertIn("required gate gate", payload["error"])
                    self.assertEqual(before, git(remote, "rev-parse", "main"))
                    self.assertFalse((root / "pushes").exists())

    def test_publish_clean_blocks_required_reviews_and_unresolved_policy(self) -> None:
        for protection, rules in [
            (
                [
                    {
                        "required_pull_request_reviews": {
                            "required_approving_review_count": 1
                        }
                    }
                ],
                [[]],
            ),
            ("absent", [[{"type": "pull_request", "parameters": {}}]]),
            ("denied", [[]]),
            ("absent", "denied"),
            ("absent", []),
        ]:
            with self.subTest(
                protection=protection, rules=rules
            ), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                before = git(remote, "rev-parse", "main")
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": rules,
                        "protection": protection,
                    },
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                self.assertEqual(1, result.returncode, result.stdout)
                self.assertEqual("blocked", json.loads(result.stdout)["status"])
                self.assertEqual(before, git(remote, "rev-parse", "main"))
                self.assertFalse((root / "pushes").exists())

    def test_publish_clean_preserves_completed_push_diagnostics_without_retry(
        self,
    ) -> None:
        for mode in ("normal", "bypass", "transport"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": [[]],
                        "protection": "absent",
                    },
                    push_mode=mode,
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                payload = json.loads(result.stdout)
                self.assertEqual(
                    1 if mode == "bypass" else 0, result.returncode, payload
                )
                self.assertEqual("published", payload["status"])
                self.assertTrue(payload["published"])
                self.assertEqual(mode != "bypass", payload["policy"]["compliant"])
                self.assertEqual("push\n", (root / "pushes").read_text())
                self.assertEqual(payload["remoteTip"], git(remote, "rev-parse", "main"))
                self.assertNotIn("secret-token", result.stdout + result.stderr)
                self.assertNotIn("query-secret", result.stdout + result.stderr)
                if mode == "bypass":
                    self.assertIn(
                        "Required status check gate", payload["pushDiagnostics"]
                    )
                if mode == "transport":
                    self.assertIn("connection lost", payload["pushDiagnostics"])

    def test_publish_clean_honors_legacy_statuses_and_classic_protection(self) -> None:
        for state in ("success", "pending", "failure", "error"):
            with self.subTest(state=state), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": [[]],
                        "protection": [
                            {
                                "required_status_checks": {"contexts": ["legacy"]},
                                "required_linear_history": {"enabled": False},
                            }
                        ],
                        "checks": [{"check_runs": []}],
                        "statuses": [
                            [
                                {"id": 2, "context": "legacy", "state": state},
                                {"id": 1, "context": "legacy", "state": "success"},
                            ]
                        ],
                    },
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                self.assertEqual(
                    0 if state == "success" else 1, result.returncode, result.stdout
                )
                self.assertEqual(state == "success", (root / "pushes").exists())

    def test_publish_clean_requires_both_app_bound_check_and_same_name_status(
        self,
    ) -> None:
        for state, has_check in (
            ("success", True),
            ("pending", True),
            ("failure", True),
            ("success", False),
        ):
            with self.subTest(
                state=state, has_check=has_check
            ), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                before = git(remote, "rev-parse", "main")
                check = {
                    "id": 1,
                    "name": "gate",
                    "head_sha": "$HEAD",
                    "app": {"id": 42},
                    "status": "completed",
                    "conclusion": "success",
                }
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": [
                            [
                                {
                                    "type": "required_status_checks",
                                    "parameters": {
                                        "required_status_checks": [
                                            {"context": "gate", "integration_id": 42}
                                        ]
                                    },
                                }
                            ]
                        ],
                        "protection": "absent",
                        "checks": [{"check_runs": [check] if has_check else []}],
                        "statuses": [[{"id": 2, "context": "gate", "state": state}]],
                    },
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                permitted = state == "success" and has_check
                self.assertEqual(
                    0 if permitted else 1, result.returncode, result.stdout
                )
                self.assertEqual(permitted, (root / "pushes").exists())
                if not permitted:
                    self.assertEqual(before, git(remote, "rev-parse", "main"))
                    self.assertIn(
                        "required gate gate", json.loads(result.stdout)["error"]
                    )

    def test_publish_clean_uses_destination_policy_despite_gh_host(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            _, revision = self.create_task_revision(repo, root)
            before = git(remote, "rev-parse", "main")
            env = self.publisher_policy_environment(
                root,
                remote,
                {
                    "rules": [[{"type": "pull_request", "parameters": {}}]],
                    "protection": "absent",
                },
            )
            env["GH_HOST"] = "enterprise.example.invalid"
            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                revision,
                cwd=repo,
                env=env,
            )
            self.assertEqual(1, result.returncode, result.stdout)
            self.assertIn("pull_request", json.loads(result.stdout)["error"])
            self.assertFalse((root / "pushes").exists())
            self.assertEqual(before, git(remote, "rev-parse", "main"))

    def test_publish_clean_allows_linear_history_without_requiring_pr(self) -> None:
        for classic in (True, False):
            with self.subTest(classic=classic), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                git(repo, "switch", "-c", "historical-side")
                (repo / "side.txt").write_text("side\n")
                git(repo, "add", "side.txt")
                git(repo, "commit", "-m", "historical side")
                git(repo, "switch", "main")
                git(
                    repo,
                    "merge",
                    "--no-ff",
                    "historical-side",
                    "-m",
                    "historical merge",
                )
                git(repo, "push", "origin", "main")
                _, revision = self.create_task_revision(repo, root)
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": (
                            [[]] if classic else [[{"type": "required_linear_history"}]]
                        ),
                        "protection": (
                            [{"required_linear_history": {"enabled": True}}]
                            if classic
                            else "absent"
                        ),
                    },
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                payload = json.loads(result.stdout)
                self.assertEqual(0, result.returncode, payload)
                self.assertTrue(payload["policy"]["compliant"])
                self.assertEqual("push\n", (root / "pushes").read_text())
                self.assertEqual(payload["remoteTip"], git(remote, "rev-parse", "main"))

    def test_publish_clean_bounds_retries_to_non_fast_forward_rejections(self) -> None:
        for mode, count in (("reject", 2), ("policy-reject", 1)):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo, remote = self.init_repo(root)
                _, revision = self.create_task_revision(repo, root)
                before = git(remote, "rev-parse", "main")
                env = self.publisher_policy_environment(
                    root,
                    remote,
                    {
                        "rules": [[]],
                        "protection": "absent",
                    },
                    push_mode=mode,
                )
                result = self.run_publish_clean(
                    "--source-repo",
                    str(repo),
                    "--task-revision",
                    revision,
                    cwd=repo,
                    env=env,
                )
                self.assertEqual(1, result.returncode, result.stdout)
                self.assertEqual("blocked", json.loads(result.stdout)["status"])
                self.assertEqual(before, git(remote, "rev-parse", "main"))
                self.assertEqual("push\n" * count, (root / "pushes").read_text())

    @unittest.skipUnless(shutil.which("jj"), "jj is not installed")
    def test_jj_snapshot_and_verify_classification_are_structured(self) -> None:
        for colocation in ("--colocate", "--no-colocate"):
            with self.subTest(colocation=colocation):
                self.assert_jj_snapshot_preservation(colocation)

    def assert_jj_snapshot_preservation(self, colocation: str) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, remote = self.init_repo(root)
            repo = root / "jjrepo"
            subprocess.run(
                ["jj", "git", "clone", colocation, str(remote), str(repo)],
                check=True,
                capture_output=True,
                text=True,
            )
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            self.assertEqual(snapshot.returncode, 0, snapshot.stderr)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)
            payload = json.loads(snapshot.stdout)
            self.assertEqual(payload["backend"], "jj")
            self.assertEqual(payload["destination"]["remote"], "origin")
            self.assertTrue(payload["workingCopy"]["clean"])

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-revision",
                "@",
                "--authority",
                "verify",
                cwd=repo,
            )
            self.assertEqual(result.returncode, 1)
            classified = json.loads(result.stdout)
            self.assertEqual(classified["status"], "blocked")
            self.assertEqual(classified["taskRevisions"][0]["evidence"], "unlanded")

            def recorded_state():
                state = {
                    str(path.relative_to(repo)): path.read_bytes()
                    for directory in (
                        repo / ".jj/working_copy",
                        repo / ".jj/repo/op_heads",
                    )
                    for path in directory.rglob("*")
                    if path.is_file()
                }
                if (repo / ".git/index").exists():
                    state[".git/index"] = (repo / ".git/index").read_bytes()
                return state

            recorded_before = recorded_state()
            base = (repo / "base.txt").read_bytes()
            for name in ("base.txt", "untracked \n.txt"):
                with self.subTest(name=name):
                    changed_file = repo / name
                    changed_file.write_bytes(b"first\x00\xff")
                    changed = self.run_closeout(
                        "verify-preservation",
                        "--snapshot",
                        str(snapshot_path),
                        cwd=root,
                    )
                    self.assertEqual(
                        changed.returncode, 1, changed.stdout + changed.stderr
                    )
                    dirty = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
                    self.assertEqual(dirty.returncode, 0, dirty.stderr)
                    self.assertFalse(json.loads(dirty.stdout)["workingCopy"]["clean"])
                    dirty_path = root / "dirty.json"
                    dirty_path.write_text(dirty.stdout)
                    unchanged = self.run_closeout(
                        "verify-preservation", "--snapshot", str(dirty_path), cwd=root
                    )
                    self.assertEqual(unchanged.returncode, 0, unchanged.stderr)
                    changed_file.write_bytes(b"second\x00\xff")
                    changed_again = self.run_closeout(
                        "verify-preservation", "--snapshot", str(dirty_path), cwd=root
                    )
                    self.assertEqual(
                        changed_again.returncode,
                        1,
                        changed_again.stdout + changed_again.stderr,
                    )
                    self.assertEqual(recorded_state(), recorded_before)
                    if name == "base.txt":
                        changed_file.write_bytes(base)
                    else:
                        changed_file.unlink()
