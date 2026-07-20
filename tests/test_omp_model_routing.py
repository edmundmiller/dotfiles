import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OmpModelRoutingTests(unittest.TestCase):
    def test_mactraitorpro_uses_requested_sol_efforts(self) -> None:
        for role, effort in (("default", "medium"), ("designer", "high"), ("slow", "xhigh")):
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

    def test_mactraitorpro_uses_gemini_3_flash_for_vision(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--raw",
                ".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp.modelRoles.vision",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "google-antigravity/gemini-3-flash")

    def test_mactraitorpro_uses_cross_provider_k3_fallbacks(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                ".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp.retry.fallbackChains",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        chains = json.loads(result.stdout)
        for role in ("default", "plan", "slow"):
            with self.subTest(role=role):
                self.assertNotIn("opencode-go/glm-5.2", chains[role])
                self.assertIn("openrouter/moonshotai/kimi-k3:high", chains[role])


if __name__ == "__main__":
    unittest.main()
