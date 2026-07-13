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

    @unittest.expectedFailure
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

    @unittest.expectedFailure
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


if __name__ == "__main__":
    unittest.main()
