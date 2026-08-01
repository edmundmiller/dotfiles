from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class OpenWikiGitMutationLaneTest(unittest.TestCase):
    def test_schedule_never_mutates_the_live_vault_checkout(self) -> None:
        source = (ROOT / "packages/openwiki/default.nix").read_text()

        self.assertIn("openwikiScheduledIngestion", source)
        self.assertIn(".local/state/openwiki/obsidian-vault", source)
        self.assertIn('git -C "$repo" push origin HEAD:main', source)
        self.assertIn("for attempt in 1 2 3 4 5", source)
        self.assertIn('merge-base --is-ancestor "$mutation_tip" "$remote_tip"', source)
        self.assertIn("ls-remote origin refs/heads/main", source)
        self.assertNotIn('"%s/obsidian-vault"', source)


if __name__ == "__main__":
    unittest.main()
