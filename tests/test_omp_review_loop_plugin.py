import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REVIEW_LOOP_SOURCE = (
    "git:github.com/earendil-works/pi-review-loop"
    "#3822e126b8b9ec05d7796b7897512c773ba9a166"
)


class OmpReviewLoopPluginTests(unittest.TestCase):
    def test_mactraitorpro_installs_pinned_review_loop_plugin(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--raw",
                ".#darwinConfigurations.MacTraitor-Pro.config.home-manager.users."
                "emiller.home.activation.omp-review-loop-plugin.data",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("omp plugin install", result.stdout)
        self.assertIn(REVIEW_LOOP_SOURCE, result.stdout)
        self.assertIn("--force --json", result.stdout)
        self.assertIn("omp plugin uninstall pi-review-loop", result.stdout)
        self.assertIn("/bin/sed", result.stdout)
        self.assertIn('if (ctx.mode !== "tui")', result.stdout)
        self.assertIn("if (!ctx.hasUI)", result.stdout)
        self.assertIn('"$review_loop_dir/src/index.ts"', result.stdout)
        self.assertNotIn("/bin/patch", result.stdout)
        self.assertIn("/usr/bin/swiftc", result.stdout)
        self.assertIn("glimpseui", result.stdout)
        self.assertIn("glimpse.swift", result.stdout)


if __name__ == "__main__":
    unittest.main()
