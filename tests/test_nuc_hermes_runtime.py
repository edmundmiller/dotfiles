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

        self.assertIn("amosburtonCronExecutor", service)
        self.assertIn(
            'writeShellScript "hermes-amosburton-cron-executor"', source
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

    @unittest.expectedFailure
    def test_shared_profile_metadata_uses_canonical_purposes(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        start = source.index("hermesSharedProfilesAggregate = {")
        end = source.index("hermesAmosburtonSecretsMaterialize = {", start)
        activation = source[start:end]

        self.assertIn(
            "hermesAgentSpecs = import (inputs.agents-workspace + /agents/registry.nix)",
            source,
        )
        self.assertIn("description = hermesAgentSpecs.${profile}.purpose;", source)
        self.assertIn("description_auto = false;", source)
        self.assertIn("install -o emiller -g users -m 0640", activation)
        self.assertIn('rm -f "$SHARED_HOME/profiles/"*', activation)
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
            "github:NousResearch/hermes-agent/5b5932886ce6477a0f4a3d25ca465392288d5126",
            flake,
        )


if __name__ == "__main__":
    unittest.main()
