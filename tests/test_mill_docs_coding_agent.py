from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MillDocsCodingAgentTest(unittest.TestCase):
    def test_nuc_runs_queue_from_a_dedicated_checkout(self) -> None:
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn('millDocsCodingAgentRepo = "/var/lib/mill-docs-coding-agent/repo";', source)
        self.assertIn("systemd.services.mill-docs-coding-agent", source)
        self.assertIn("systemd.timers.mill-docs-coding-agent", source)
        self.assertIn('BUZZ_FEEDBACK_STATUS_URL = "https://mill-docs-agents.${tailnet}/channels/buzz/feedback";', source)
        self.assertIn('git remote add github', source)
        self.assertIn('export GH_TOKEN="$(< /var/lib/opnix/secrets/millDocsCodingAgentGithubToken)"', source)
        self.assertNotIn('WorkingDirectory = millDocsVaultPath;\n      ExecStart = "${millDocsCodingAgent', source)


if __name__ == "__main__":
    unittest.main()
