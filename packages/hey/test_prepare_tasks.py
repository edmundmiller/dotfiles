"""Verify local agents pin preparation never publishes or deploys."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativePrepareTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey prepare build ")
        cls.addClassCleanup(cls.build.cleanup)
        cls.binary = Path(cls.build.name) / "hey-prepare"
        subprocess.run(["bash", str(SOURCE / "build"), str(cls.binary), "/unused/mise", "prepare-main.bend"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey preparation fixture ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "dotfiles project"
        self.workspace = self.base / "agents workspace"
        self.tools = self.base / "tools"
        self.caller = self.base / "caller"
        self.home = self.base / "home"
        for directory in (self.root, self.workspace, self.tools, self.caller, self.home):
            directory.mkdir()
        self.git = shutil.which("git")
        self.git_env = os.environ | {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
        self.old_pin = "1" * 40
        self.original = f'{{ inputs.agents-workspace.url = "github:edmundmiller/agents-workspace/{self.old_pin}"; }}\n'
        (self.root / "flake.nix").write_text(self.original)
        (self.root / "flake.lock").write_text("{}\n")
        (self.root / "notes").write_text("unchanged\n")
        (self.workspace / "source").write_text("workspace revision\n")
        for repository in (self.root, self.workspace):
            self.git_command(repository, "init", "--quiet")
            self.commit(repository)
        self.root_head = self.git_command(self.root, "rev-parse", "HEAD").strip()
        self.head = self.git_command(self.workspace, "rev-parse", "HEAD").strip()
        self.log = self.base / "commands.jsonl"
        self.env = self.git_env | {
            "PATH": str(self.tools), "HOME": str(self.home), "MISE_PROJECT_ROOT": str(self.root),
            "HEY_PREPARE_LOG": str(self.log), "HEY_REAL_GIT": self.git, "HEY_PREPARE_HEAD": self.head,
            "NIX_CONFIG": "caller-setting = keep", "FLAKE_DIR": "/wrong-checkout",
        }
        common = (
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "assert all('fixture-gh-secret' not in arg for arg in args)\n"
            "with open(os.environ['HEY_PREPARE_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, args, os.getcwd()]) + '\\n')\n"
        )
        self.executable("git", common +
            "assert args[0] == '-C' and args[2] in ('status', 'rev-parse')\n"
            "if args[2:] == ['rev-parse', 'HEAD'] and os.environ.get('HEY_BAD_HEAD'):\n"
            "    print(os.environ['HEY_BAD_HEAD'])\n"
            "else: os.execv(os.environ['HEY_REAL_GIT'], ['git', *args])\n")
        self.executable("gh", common + "assert args == ['auth', 'token']\nprint('fixture-gh-secret')\n")
        self.executable("nix", common +
            "assert args == ['flake', 'update', 'agents-workspace']\n"
            "config = os.environ['NIX_CONFIG']\n"
            "assert 'caller-setting = keep' in config and 'access-tokens = github.com=fixture-gh-secret' in config\n"
            "if os.environ.get('HEY_NIX_FAIL') == '1': raise SystemExit(23)\n"
            "pathlib.Path('flake.lock').write_text(json.dumps({'agentsRevision': os.environ['HEY_PREPARE_HEAD']}))\n")

    def git_command(self, repository, *args):
        return subprocess.run([self.git, "-C", str(repository), *args], env=self.git_env,
                              capture_output=True, text=True, check=True).stdout

    def commit(self, repository):
        self.git_command(repository, "add", ".")
        self.git_command(repository, "-c", "user.name=Fixture", "-c", "user.email=fixture@localhost",
                         "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "fixture")

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def run_task(self, *args):
        return subprocess.run([self.binary, "agents:prepare", *args], cwd=self.caller, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_preparation_updates_only_local_pin_files_with_scoped_auth(self):
        result = self.run_task("--workspace", str(self.workspace))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "flake.nix").read_text(), self.original.replace(self.old_pin, self.head))
        self.assertEqual(json.loads((self.root / "flake.lock").read_text()), {"agentsRevision": self.head})
        self.assertEqual(self.git_command(self.root, "rev-parse", "HEAD").strip(), self.root_head)
        self.assertEqual(self.git_command(self.workspace, "rev-parse", "HEAD").strip(), self.head)
        self.assertEqual(self.git_command(self.workspace, "status", "--porcelain"), "")
        changed = self.git_command(self.root, "diff", "--name-only").splitlines()
        self.assertEqual(changed, ["flake.lock", "flake.nix"])
        self.assertEqual(self.operations()[-1], ["nix", ["flake", "update", "agents-workspace"], str(self.root)])
        self.assertEqual(self.env["NIX_CONFIG"], "caller-setting = keep")
        self.assertNotIn("fixture-gh-secret", result.stdout + result.stderr + self.log.read_text())
        self.assertIn("separate approval", result.stdout)

    def test_dirty_workspace_or_dotfiles_cannot_change_a_pin(self):
        for repository, file in ((self.workspace, "source"), (self.root, "notes")):
            with self.subTest(repository=repository):
                self.log.unlink(missing_ok=True)
                path = repository / file
                original = path.read_text()
                path.write_text("user work must remain\n")
                result = self.run_task("--workspace", str(self.workspace))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "flake.nix").read_text(), self.original)
                self.assertFalse(any(name in ("gh", "nix") for name, args, cwd in self.operations()))
                self.assertEqual(path.read_text(), "user work must remain\n")
                path.write_text(original)

    def test_malformed_workspace_revision_is_rejected_before_writing(self):
        for revision in ("a" * 39, "A" * 40, "g" * 40, "a" * 41):
            with self.subTest(revision=revision):
                self.env["HEY_BAD_HEAD"] = revision
                result = self.run_task("--workspace", str(self.workspace))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "flake.nix").read_text(), self.original)
                self.assertFalse(any(name == "nix" for name, args, cwd in self.operations()))

    def test_missing_duplicate_and_malformed_source_pins_are_not_rewritten(self):
        candidates = ["{}\n", self.original + f'# github:edmundmiller/agents-workspace/{self.old_pin}\n',
                      self.original.replace(self.old_pin, self.old_pin + "a"),
                      self.original + f'# github:edmundmiller/agents-workspace/{self.old_pin}g\n']
        for source in candidates:
            with self.subTest(source=source):
                (self.root / "flake.nix").write_text(source)
                self.commit(self.root)
                self.log.unlink(missing_ok=True)
                result = self.run_task("--workspace", str(self.workspace))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "flake.nix").read_text(), source)
                self.assertFalse(any(name == "nix" for name, args, cwd in self.operations()))

    def test_default_workspace_and_inline_path_option_are_supported(self):
        default = self.home / "src/personal/agents-workspace"
        default.parent.mkdir(parents=True)
        default.symlink_to(self.workspace)
        result = self.run_task()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.git_command(self.root, "restore", "flake.nix", "flake.lock")
        self.log.unlink()
        inline = self.run_task("--workspace=" + str(self.workspace))
        self.assertEqual(inline.returncode, 0, inline.stderr)
        self.assertTrue(any(args[:2] == ["-C", str(self.workspace)] for name, args, cwd in self.operations() if name == "git"))

    def test_nix_failure_cannot_publish_commit_or_deploy(self):
        self.env["HEY_NIX_FAIL"] = "1"
        result = self.run_task("--workspace", str(self.workspace))
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertNotIn("Prepared agents-workspace pin", result.stdout)
        self.assertIn("Review local pin changes", result.stderr)
        self.assertEqual((self.root / "flake.lock").read_text(), "{}\n")
        self.assertEqual(self.git_command(self.root, "rev-parse", "HEAD").strip(), self.root_head)
        self.assertEqual([name for name, args, cwd in self.operations()], ["git", "git", "git", "gh", "nix"])
        self.assertTrue(all(args[2] in ("status", "rev-parse") for name, args, cwd in self.operations() if name == "git"))

    def test_legacy_rollout_flags_and_commit_message_are_rejected(self):
        for args in (("--deploy-mode", "switch"), ("chore: bump agents-workspace",), ("--workspace",)):
            with self.subTest(args=args):
                result = self.run_task(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.operations(), [])


if __name__ == "__main__":
    unittest.main()
