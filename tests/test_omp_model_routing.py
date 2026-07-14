import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OmpModelRoutingTests(unittest.TestCase):
    def test_mactraitorpro_default_is_sol_low(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--raw",
                ".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp.modelRoles.default",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "openai-codex/gpt-5.6-sol:low")


if __name__ == "__main__":
    unittest.main()
