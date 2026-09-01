import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class NucHermesRuntimeTest(unittest.TestCase):

    def test_amos_cron_uses_canonical_linear_api_credential(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        service_start = source.index("systemd.services.hermes-amosburton-cron-tick")
        service_end = source.index(
            "systemd.timers.hermes-amosburton-cron-tick", service_start
        )
        service = source[service_start:service_end]

        self.assertIn(
            'ExecStart = "${hermesAgentBase}/bin/hermes cron tick";',
            service,
        )
        self.assertIn("amosburtonAgentSpec.hermes.dotenvReferences.LINEAR_API_KEY", source)
        self.assertIn("hermes-amosburton-secrets-materialize.service", service)
        self.assertIn(
            '"/run/hermes-amosburton-env/secrets.env"',
            service,
        )

    def test_scintillate_cron_pins_profile_home_for_terminal_tools(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        service_start = source.index("systemd.services.hermes-scintillate-cron-tick")
        service_end = source.index(
            "systemd.timers.hermes-scintillate-cron-tick", service_start
        )
        service = source[service_start:service_end]

        self.assertIn('HOME = "/var/lib/hermes-scintillate"', service)
        self.assertIn(
            'HERMES_HOME = "/var/lib/hermes-scintillate/.hermes"', service
        )
        self.assertIn('HERMES_REAL_HOME = "/var/lib/hermes-scintillate"', service)
        self.assertIn('TERMINAL_HOME_MODE = "real"', service)

    def test_scintillate_login_snapshot_restores_profile_hermes_home(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        profile_start = source.index("scintillate = {")
        profile_end = source.index("amosburton = {", profile_start)
        profile = source[profile_start:profile_end]

        self.assertIn("scintillateTerminalInit = pkgs.writeText", source)
        self.assertIn(
            "export HERMES_HOME=/var/lib/hermes-scintillate/.hermes", source
        )
        self.assertIn(
            'shell_init_files = [ "${scintillateTerminalInit}" ];', profile
        )

    def test_shared_profile_aggregation_preserves_runtime_owned_metadata(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        start = source.index("hermesSharedProfilesAggregate = {")
        end = source.index("hermesAmosburtonSecretsMaterialize = {", start)
        activation = source[start:end]

        self.assertIn(
            'find "$SHARED_HOME/profiles" -mindepth 1 -maxdepth 1 -type l -delete',
            activation,
        )
        self.assertNotIn('rm -f "$SHARED_HOME/profiles/"*', activation)
        self.assertIn('ln -s "$profile_home" "$aggregate_link"', activation)
        self.assertNotIn('"$profile_home/profile.yaml"', activation)
        self.assertNotIn(
            'if [ -d "$profile_home" ] && [ ! -f "$profile_home/profile.yaml" ]',
            activation,
        )

    def test_orchestrator_worker_profiles_have_managed_runtime_shape(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        start = source.index('"hermes-orchestrator-profile-list-mirror"')
        end = source.index("systemd.services.hermes-gateway-orchestrator.enable", start)
        mirror = source[start:end]

        self.assertIn(
            '"$dst" "$dst/cron" "$dst/sessions" "$dst/logs" "$dst/memories"',
            mirror,
        )
        self.assertIn("for file in config.yaml profile.yaml SOUL.md", mirror)
        self.assertIn("for dir in skills shared-skills", mirror)
        for private_state in (".env", "auth.json", "honcho.json", "state.db"):
            self.assertNotIn(f'"$src/{private_state}"', mirror)

    def test_hermes_revision_includes_profile_descriptions(self):
        flake = (ROOT / "flake.nix").read_text()
        self.assertIn(
            "github:NousResearch/hermes-agent/29112bef099274229cadff79cdff7bf7b99c4b77",
            flake,
        )

    def test_generic_hermes_runtime_policy_clears_stale_app_server_selection(self):
        policy = ROOT / "lib/hermes.nix"
        expression = f'''
let
  render = (import {policy} {{ lib = (builtins.getFlake "nixpkgs").lib; }}).renderHermesSettings;
in
  render {{
    timezone = "America/Chicago";
    settings = {{
      model = {{
        openai_runtime = "codex_app_server";
        temperature = 0.2;
      }};
      kanban.dispatch_in_gateway = false;
      custom = {{ preserve = true; }};
    }};
  }}
'''
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            check=True,
            capture_output=True,
            text=True,
        )
        rendered = json.loads(result.stdout)

        self.assertEqual(rendered["model"]["openai_runtime"], "auto")
        self.assertEqual(rendered["model"]["temperature"], 0.2)
        self.assertFalse(rendered["kanban"]["dispatch_in_gateway"])
        self.assertTrue(rendered["custom"]["preserve"])
        self.assertEqual(rendered["timezone"], "America/Chicago")


if __name__ == "__main__":
    unittest.main()
