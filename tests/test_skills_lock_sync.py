import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills" / "scripts" / "check-lock-sync.py"
FLAKE = ROOT / "flake.nix"


def pinned(revision: str) -> dict[str, dict[str, str]]:
    return {"locked": {"rev": revision, "type": "github"}}


def basic_locks(
    child_revision: str = "abc",
    parent_revision: str = "abc",
) -> tuple[dict, dict]:
    child = {
        "root": "root",
        "nodes": {
            "root": {"inputs": {"source": "source"}},
            "source": pinned(child_revision),
        },
    }
    parent = {
        "root": "root",
        "nodes": {
            "root": {"inputs": {"source": "root-source"}},
            "root-source": pinned(parent_revision),
            "skills-catalog": {"inputs": {"source": "child-source"}},
            "child-source": pinned(parent_revision),
        },
    }
    return child, parent


class SkillsLockSyncTests(unittest.TestCase):
    def run_check(self, child: dict, parent: dict):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            (repo / "skills").mkdir()
            (repo / "skills" / "flake.lock").write_text(json.dumps(child))
            (repo / "flake.lock").write_text(json.dumps(parent))
            return subprocess.run(
                ["python3", str(SCRIPT), str(repo)],
                capture_output=True,
                text=True,
                check=False,
            )

    def test_matching_child_pin_passes(self) -> None:
        result = self.run_check(*basic_locks())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS skills-lock-sync", result.stdout)

    def test_stale_parent_pin_fails(self) -> None:
        result = self.run_check(*basic_locks("new", "old"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parent pin is stale for child input: source", result.stderr)

    def test_parent_follow_is_an_intentional_override(self) -> None:
        child, parent = basic_locks("child", "parent")
        parent["nodes"]["skills-catalog"]["inputs"]["source"] = ["source"]
        result = self.run_check(child, parent)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_malformed_parent_follow_fails(self) -> None:
        child, parent = basic_locks()
        parent["nodes"]["skills-catalog"]["inputs"]["source"] = ["missing"]
        result = self.run_check(child, parent)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ERROR skills-lock-sync", result.stderr)

    def test_unpinned_input_fails(self) -> None:
        child, parent = basic_locks()
        child["nodes"]["source"] = {"original": {"type": "github"}}
        parent["nodes"]["child-source"] = {"original": {"type": "github"}}
        result = self.run_check(child, parent)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("input is not pinned", result.stderr)

    def test_missing_parent_input_fails(self) -> None:
        child, parent = basic_locks()
        parent["nodes"]["skills-catalog"]["inputs"].pop("source")
        result = self.run_check(child, parent)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parent is missing child inputs: source", result.stderr)

    def test_extra_parent_input_fails(self) -> None:
        child, parent = basic_locks()
        parent["nodes"]["skills-catalog"]["inputs"]["stale"] = "stale"
        parent["nodes"]["stale"] = pinned("stale")
        result = self.run_check(child, parent)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parent has stale child inputs: stale", result.stderr)

    def test_one_stale_pin_among_multiple_inputs_fails(self) -> None:
        child, parent = basic_locks()
        child["nodes"]["root"]["inputs"]["second"] = "second"
        child["nodes"]["second"] = pinned("new")
        parent["nodes"]["skills-catalog"]["inputs"]["second"] = "child-second"
        parent["nodes"]["child-second"] = pinned("old")
        result = self.run_check(child, parent)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parent pin is stale for child input: second", result.stderr)

    def test_pre_commit_hook_runs_both_lock_checks(self) -> None:
        flake = FLAKE.read_text()
        hook_start = flake.index("skills-lock-sync = {")
        hook = flake[hook_start : hook_start + 700]
        self.assertIn("set -euo pipefail", hook)
        self.assertIn('nix flake lock --no-update-lock-file "$PWD/skills"', hook)
        self.assertIn("skills/scripts/check-lock-sync.py", hook)
        self.assertIn('"$PWD"', hook)
        self.assertIn("always_run = true;", hook)


if __name__ == "__main__":
    unittest.main()
