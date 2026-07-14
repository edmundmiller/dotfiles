import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OmpModelRoutingTests(unittest.TestCase):
    def test_mactraitorpro_uses_requested_sol_efforts(self) -> None:
        for role, effort in (("default", "medium"), ("slow", "xhigh")):
            with self.subTest(role=role):
                result = subprocess.run(
                    [
                        "nix",
                        "eval",
                        "--raw",
                        f".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp.modelRoles.{role}",
                        "--no-write-lock-file",
                    ],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                    check=False,
                )

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, f"openai-codex/gpt-5.6-sol:{effort}")


if __name__ == "__main__":
    unittest.main()
