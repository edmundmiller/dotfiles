import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


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
                ["bash", str(ROOT / "mise-tasks/skills/amp-stage-done"), tmp],
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
            self.assertIn('"scripts/closeout.py"', result.stdout)
            self.assertIn('"scripts/publish-clean.py"', result.stdout)

    def test_staging_refuses_local_target_edits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["git", "init", "--quiet", tmp], check=True)
            bundle = Path(tmp) / "done"
            bundle.mkdir()
            entrypoint = bundle / "SKILL.md"
            entrypoint.write_text("local work\n")
            result = subprocess.run(
                ["bash", str(ROOT / "mise-tasks/skills/amp-stage-done"), tmp],
                cwd=ROOT,
                env={**os.environ, "MISE_PROJECT_ROOT": str(ROOT)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("Refusing to overwrite", result.stderr)
            self.assertEqual(entrypoint.read_text(), "local work\n")
            self.assertEqual(list(bundle.iterdir()), [entrypoint])

    def test_rejects_stale_missing_and_extra_bundle_files(self) -> None:
        for relative, contents in (
            ("scripts/closeout.py", "stale detector\n"),
            ("scripts/publish-clean.py", "stale publisher\n"),
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
