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

    @unittest.expectedFailure
    def test_secret_reads_do_not_mask_failures(self) -> None:
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn('LINEAR_API_KEY="$(< /var/lib/opnix/secrets/amosburtonLinearApiKey)"\n      export LINEAR_API_KEY', source)
        self.assertIn('GH_TOKEN="$(< /var/lib/opnix/secrets/millDocsCodingAgentGithubToken)"\n      export GH_TOKEN', source)
        self.assertIn('BUZZ_FEEDBACK_STATUS_SECRET="$(< /home/emiller/.local/share/mill-docs-agents/tailnet-proxy-secret)"\n      export BUZZ_FEEDBACK_STATUS_SECRET', source)


if __name__ == "__main__":
    unittest.main()
