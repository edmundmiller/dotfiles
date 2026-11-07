import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from tests.test_done_closeout import git


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "skills/catalog/done"
CHECK = ROOT / "scripts/check_done_bundle.py"


class DoneDeliveryTest(unittest.TestCase):
    def check_bundle(self, bundle: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECK), str(bundle)],
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )

    @unittest.skipUnless(shutil.which("jj"), "working-jj parity requires jj")
    def test_materialized_bundle_runs_existing_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "done"
            subprocess.run(["git", "init", "--quiet", tmp], check=True)
            result = subprocess.run(
                ["bash", str(ROOT / "bin/hey.d/skills/amp-stage-done"), tmp],
                cwd=ROOT,
                env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                (bundle / "references/git.md").read_bytes(),
                (SOURCE / "references/git.md").read_bytes(),
            )
            self.assertIn('"scripts/closeout.bend"', result.stdout)
            self.assertIn('"scripts/publish-clean.bend"', result.stdout)

    @unittest.skipUnless(shutil.which("jj"), "working-jj parity requires jj")
    def test_staging_removes_obsolete_files_in_clones_and_worktrees(self) -> None:
        for linked in (False, True):
            with self.subTest(linked=linked), tempfile.TemporaryDirectory() as tmp:
                repo = Path(tmp) / "repository"
                repo.mkdir()
                git(repo, "init", "--quiet", "-b", "main")
                (repo / "done").mkdir()
                (repo / "done/obsolete.txt").write_text("tracked old resource\n")
                git(repo, "add", "done")
                git(
                    repo,
                    "-c", "user.name=Delivery Test",
                    "-c", "user.email=delivery@example.invalid",
                    "-c", "commit.gpgsign=false",
                    "commit", "--quiet", "-m", "old bundle",
                )
                target = repo
                if linked:
                    target = Path(tmp) / "worktree"
                    git(repo, "worktree", "add", "--detach", str(target))
                    self.assertTrue((target / ".git").is_file())
                result = subprocess.run(
                    ["bash", str(ROOT / "bin/hey.d/skills/amp-stage-done"), str(target)],
                    cwd=ROOT,
                    env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT)},
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse((target / "done/obsolete.txt").exists())
                self.assertEqual(
                    git(target, "diff", "--name-only", "--diff-filter=D"),
                    "done/obsolete.txt",
                )
                self.assertEqual(
                    (target / "done/scripts/publish-clean.bend").read_bytes(),
                    (SOURCE / "scripts/publish-clean.bend").read_bytes(),
                )

    @unittest.skipUnless(shutil.which("jj"), "working-jj parity requires jj")
    def test_failed_or_interrupted_replacement_preserves_old_bundle(self) -> None:
        for interrupt in (False, True):
            with self.subTest(interrupt=interrupt), tempfile.TemporaryDirectory() as tmp:
                # Match Git's canonical target when TMPDIR uses macOS's /tmp symlink.
                repo = Path(tmp).resolve() / "repository"
                repo.mkdir()
                git(repo, "init", "--quiet", "-b", "main")
                (repo / "done").mkdir()
                old = repo / "done/old.txt"
                old.write_text("original tracked bundle\n")
                git(repo, "add", "done")
                git(
                    repo,
                    "-c", "user.name=Delivery Test",
                    "-c", "user.email=delivery@example.invalid",
                    "-c", "commit.gpgsign=false",
                    "commit", "--quiet", "-m", "old bundle",
                )
                head = git(repo, "rev-parse", "HEAD")
                tools = Path(tmp) / "bin"
                tools.mkdir()
                wrapper = tools / "mv"
                wrapper.write_text(f"""#!{sys.executable}
import os
from pathlib import Path
import signal
import sys
if Path(sys.argv[-2]).name == "done" and sys.argv[-1] == {str(repo / "done")!r}:
    if {interrupt!r}:
        os.kill(os.getppid(), signal.SIGTERM)
    sys.exit(1)
os.execv({shutil.which("mv")!r}, [{shutil.which("mv")!r}, *sys.argv[1:]])
""")
                wrapper.chmod(0o755)
                result = subprocess.run(
                    ["bash", str(ROOT / "bin/hey.d/skills/amp-stage-done"), str(repo)],
                    cwd=ROOT,
                    env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT),
                         "PATH": str(tools) + os.pathsep + os.environ["PATH"]},
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(old.exists(), result.stdout + result.stderr)
                self.assertEqual(old.read_text(), "original tracked bundle\n")
                self.assertEqual(git(repo, "status", "--porcelain"), "")
                self.assertEqual(git(repo, "rev-parse", "HEAD"), head)

    def test_staging_refuses_local_target_edits(self) -> None:
        for ignored in (False, True):
            with self.subTest(ignored=ignored), tempfile.TemporaryDirectory() as tmp:
                subprocess.run(["git", "init", "--quiet", tmp], check=True)
                if ignored:
                    (Path(tmp) / ".gitignore").write_text("done/\n")
                bundle = Path(tmp) / "done"
                bundle.mkdir()
                entrypoint = bundle / "SKILL.md"
                entrypoint.write_text("local work\n")
                result = subprocess.run(
                    ["bash", str(ROOT / "bin/hey.d/skills/amp-stage-done"), tmp],
                    cwd=ROOT,
                    env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT)},
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("Refusing to overwrite", result.stderr)
                self.assertEqual(entrypoint.read_text(), "local work\n")
                self.assertEqual(list(bundle.iterdir()), [entrypoint])

    def test_staging_requires_repository_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["git", "init", "--quiet", tmp], check=True)
            subdir = Path(tmp) / "subdirectory"
            subdir.mkdir()
            result = subprocess.run(
                ["bash", str(ROOT / "bin/hey.d/skills/amp-stage-done"), str(subdir)],
                cwd=ROOT,
                env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertEqual(list(subdir.iterdir()), [])

    def test_rejects_stale_missing_and_extra_bundle_files(self) -> None:
        for relative, contents in (
            ("scripts/closeout.bend", "stale detector\n"),
            ("scripts/publish-clean.bend", "stale publisher\n"),
            ("SKILL.md", None),
            ("obsolete.txt", "old resource\n"),
        ):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as tmp:
                bundle = Path(tmp) / "done"
                shutil.copytree(SOURCE, bundle)
                path = bundle / relative
                if contents is None:
                    path.unlink()
                else:
                    path.write_text(contents)
                result = self.check_bundle(bundle)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(relative, result.stderr)
                self.assertIn("differs from canonical", result.stderr)
