import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "bin" / "check-flake-portability"


class FlakePortabilityTests(unittest.TestCase):
    def run_checker(self, *paths: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(CHECKER), *(str(path) for path in paths)],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_rejects_absolute_local_git_input_in_lock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lock = Path(tmp) / "flake.lock"
            lock.write_text(
                json.dumps(
                    {
                        "nodes": {
                            "skills-catalog": {
                                "locked": {
                                    "type": "git",
                                    "url": "file:///Users/alice/.config/dotfiles",
                                },
                                "original": {
                                    "type": "git",
                                    "url": "file:///Users/alice/.config/dotfiles",
                                },
                            }
                        }
                    }
                )
            )

            result = self.run_checker(lock)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("skills-catalog", result.stderr)
            self.assertIn("./skills", result.stderr)

    def test_rejects_absolute_local_git_input_in_source(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            flake = Path(tmp) / "flake.nix"
            flake.write_text(
                'skills-catalog.url = "git+file:///Users/alice/.config/dotfiles?dir=skills";\n'
            )

            result = self.run_checker(flake)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("flake.nix", result.stderr)
            self.assertIn("./skills", result.stderr)

    def test_rejects_absolute_local_path_input_in_lock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lock = Path(tmp) / "flake.lock"
            lock.write_text(
                json.dumps(
                    {
                        "nodes": {
                            "skills-catalog": {
                                "locked": {
                                    "type": "path",
                                    "path": "/Users/alice/.config/dotfiles/skills",
                                },
                                "original": {
                                    "type": "path",
                                    "path": "/Users/alice/.config/dotfiles/skills",
                                },
                            }
                        }
                    }
                )
            )

            result = self.run_checker(lock)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("skills-catalog", result.stderr)

    def test_accepts_relative_path_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            flake = root / "flake.nix"
            lock = root / "flake.lock"
            flake.write_text('skills-catalog.url = "./skills";\n')
            lock.write_text(
                json.dumps(
                    {
                        "nodes": {
                            "skills-catalog": {
                                "locked": {"type": "path", "path": "./skills"},
                                "original": {"type": "path", "path": "./skills"},
                            }
                        }
                    }
                )
            )

            result = self.run_checker(flake, lock)

            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
