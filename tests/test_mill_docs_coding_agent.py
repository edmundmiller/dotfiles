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
        self.assertNotIn('WorkingDirectory = millDocsVaultPath;\n      ExecStart = "${millDocsCodingAgent', source)

    @unittest.expectedFailure
    def test_secret_reads_do_not_mask_failures(self) -> None:
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn('LINEAR_API_KEY="$(< "$CREDENTIALS_DIRECTORY/linear-api-key")"', source)
        self.assertIn('GH_TOKEN="$(< "$CREDENTIALS_DIRECTORY/github-token")"', source)
        self.assertIn('"linear-api-key:/var/lib/opnix/secrets/amosburtonLinearApiKey"', source)
        self.assertIn('"github-token:/var/lib/opnix/secrets/millDocsCodingAgentGithubToken"', source)
        self.assertIn('BUZZ_FEEDBACK_STATUS_SECRET="$(< /home/emiller/.local/share/mill-docs-agents/tailnet-proxy-secret)"', source)
        self.assertIn("export LINEAR_API_KEY GH_TOKEN BUZZ_FEEDBACK_STATUS_SECRET", source)

    def test_mutable_agent_state_is_service_owned(self) -> None:
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn('XDG_DATA_HOME = "${millDocsCodingAgentStateDir}/data";', source)
        self.assertIn('XDG_CACHE_HOME = "${millDocsCodingAgentStateDir}/cache";', source)
        self.assertIn('NPM_CONFIG_CACHE = "${millDocsCodingAgentStateDir}/cache/npm";', source)
        self.assertNotIn('"/home/emiller/.local/share/omp"', source)

    def test_buzz_git_uses_nostr_credential_helper(self) -> None:
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn('git -c credential.useHttpPath=true -c credential.helper=${pkgs.my.buzz}/bin/git-credential-nostr clone', source)
        self.assertIn('git config credential.helper ${pkgs.my.buzz}/bin/git-credential-nostr', source)
        self.assertIn('git config credential.useHttpPath true', source)
        self.assertIn('export NOSTR_PRIVATE_KEY="$BUZZ_PRIVATE_KEY"', source)
        self.assertIn('unset NOSTR_PRIVATE_KEY BUZZ_PRIVATE_KEY', source)
        self.assertIn('EnvironmentFile = config.age.secrets.buzz-mill-docs-agent-env.path;', source)

    def test_buzz_package_installs_git_credential_helper(self) -> None:
        source = (ROOT / "packages/buzz/default.nix").read_text()
        self.assertIn('"--package=git-credential-nostr"', source)
        nuc_source = (ROOT / "hosts/nuc/default.nix").read_text()
        self.assertIn("runtimeInputs = [\n      pkgs.coreutils\n      pkgs.bash\n      pkgs.git\n      pkgs.git-lfs\n      pkgs.gh", nuc_source)
        self.assertIn("export GIT_LFS_SKIP_SMUDGE=1", nuc_source)


if __name__ == "__main__":
    unittest.main()
