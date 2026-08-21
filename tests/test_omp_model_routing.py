import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def nix_path() -> str:
    # Prefer the system-managed nix: older profile/PATH versions ignore the
    # flake's nixConfig as untrusted and fail on dynamic-derivations.
    system_nix = Path("/run/current-system/sw/bin/nix")
    if system_nix.is_file():
        return str(system_nix)
    return shutil.which("nix") or "nix"



class OmpConfigYmlDefaultsTests(unittest.TestCase):
    def test_advisor_uses_only_supported_settings(self) -> None:
        text = (ROOT / "config" / "omp" / "config.yml").read_text()
        self.assertNotIn("  subagents:", text)


class OmpModelRoutingTests(unittest.TestCase):
    def test_mactraitorpro_uses_requested_sol_efforts(self) -> None:
        for role, effort in (("default", "medium"), ("slow", "xhigh")):
            with self.subTest(role=role):
                result = subprocess.run(
                    [
                        nix_path(),
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

    def test_mactraitorpro_routes_prewalk_and_metadata_roles_separately(
        self,
    ) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                ".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        omp = json.loads(result.stdout)
        self.assertEqual(omp["smolModel"], "openai-codex/gpt-5.6-sol:low")
        self.assertNotIn("smol", omp["modelRoles"])
        self.assertEqual(omp["modelRoles"]["task"], "openai-codex/gpt-5.6-luna:xhigh")
        self.assertEqual(
            omp["modelRoles"]["tiny"],
            "openai-codex/gpt-5.6-luna:low",
        )
        self.assertEqual(
            omp["modelRoles"]["commit"],
            "openai-codex/gpt-5.6-luna:low",
        )

    def test_mactraitorpro_uses_subscription_k3_for_designer(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--raw",
                ".#darwinConfigurations.MacTraitor-Pro.config.modules.agents.omp.modelRoles.designer",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "opencode-go/kimi-k3:high")

    def test_mactraitorpro_uses_gemini_3_5_flash_for_vision(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
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
        self.assertEqual(result.stdout, "google-antigravity/gemini-3.5-flash")

    def test_mactraitorpro_prefers_subscription_k3_before_openrouter(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
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
                self.assertEqual(
                    chains[role][-2:],
                    [
                        "opencode-go/kimi-k3:high",
                        "openrouter/moonshotai/kimi-k3:high",
                    ],
                )
        self.assertEqual(chains["task"][0], "openai-codex/gpt-5.6-sol:xhigh")
        self.assertEqual(chains["commit"][0], "openai-codex/gpt-5.6-sol:low")
        self.assertEqual(chains["tiny"][0], "openai-codex/gpt-5.6-sol:low")
        self.assertIn("openai-codex/gpt-5.6-sol:low", chains["smol"])

    def test_seqeratop_routes_prewalk_and_metadata_roles_separately(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                ".#darwinConfigurations.Seqeratop.config.modules.agents.omp",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        omp = json.loads(result.stdout)
        self.assertEqual(omp["smolModel"], "openai-codex/gpt-5.6-sol:low")
        self.assertEqual(omp["modelRoles"]["smol"], "openai-codex/gpt-5.6-sol:low")
        self.assertEqual(
            omp["modelRoles"]["default"],
            "openai-codex/gpt-5.6-sol:medium",
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["default"],
            [
                "openai-codex/gpt-5.6-luna:medium",
                "cursor/cursor-grok-4.6-medium",
                "cursor/composer-2.5-fast",
            ],
        )
        self.assertEqual(
            omp["modelRoles"]["commit"],
            "openai-codex/gpt-5.6-luna:low",
        )
        self.assertEqual(
            omp["modelRoles"]["tiny"],
            "openai-codex/gpt-5.6-luna:low",
        )
        self.assertEqual(omp["modelRoles"]["task"], "openai-codex/gpt-5.6-luna:xhigh")
        self.assertEqual(omp["modelRoles"]["slow"], "openai-codex/gpt-5.6-sol:xhigh")
        self.assertEqual(
            omp["modelRoles"]["advisor"],
            "openai-codex/gpt-5.6-sol:high",
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["advisor"],
            [
                "openai-codex/gpt-5.6-luna:high",
                "cursor/cursor-grok-4.6-high",
                "cursor/composer-2.5-fast",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["slow"],
            [
                "openai-codex/gpt-5.6-terra:high",
                "openai-codex/gpt-5.6-luna:high",
                "cursor/cursor-grok-4.6-xhigh",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["smol"],
            [
                "openai-codex/gpt-5.6-luna",
                "cursor/cursor-grok-4.6-low-fast",
                "cursor/composer-2.5-fast",
            ],
        )
        self.assertEqual(omp["modelRoles"]["plan"], "openai-codex/gpt-5.6-sol:high")
        self.assertEqual(
            omp["modelRoles"]["designer"],
            "openai-codex/gpt-5.6-sol:high",
        )
        self.assertEqual(
            omp["modelRoles"]["vision"],
            "google-antigravity/gemini-3.5-flash",
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["plan"],
            [
                "openai-codex/gpt-5.6-luna:high",
                "cursor/cursor-grok-4.6-high",
                "cursor/kimi-k3-high",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["designer"],
            [
                "openai-codex/gpt-5.6-luna:high",
                "cursor/kimi-k3-high",
                "cursor/cursor-grok-4.6-medium",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["task"],
            [
                "openai-codex/gpt-5.6-sol:xhigh",
                "cursor/cursor-grok-4.6-xhigh",
                "cursor/composer-2.5-fast",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["commit"],
            [
                "openai-codex/gpt-5.6-sol:low",
                "cursor/composer-2.5-fast",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["tiny"],
            [
                "openai-codex/gpt-5.6-sol:low",
                "cursor/composer-2.5-fast",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["vision"],
            [
                "openai-codex/gpt-5.6-sol:medium",
                "openai-codex/gpt-5.6-luna:medium",
                "cursor/gemini-3.5-flash",
            ],
        )
        self.assertEqual(
            omp["dailyIntrospection"]["model"],
            "openai-codex/gpt-5.6-sol:high",
        )
        self.assertEqual(
            omp["modelProviderOrder"][:2],
            ["openai-codex", "cursor"],
        )
        seqeratop_cursor_ids = {
            "cursor/cursor-grok-4.6-medium",
            "cursor/cursor-grok-4.6-high",
            "cursor/cursor-grok-4.6-xhigh",
            "cursor/cursor-grok-4.6-low-fast",
            "cursor/composer-2.5-fast",
            "cursor/kimi-k3-high",
            "cursor/gemini-3.5-flash",
        }
        for role, chain in omp["retry"]["fallbackChains"].items():
            with self.subTest(no_vibeproxy=role):
                self.assertTrue(
                    all(not entry.startswith("vibeproxy/") for entry in chain),
                    chain,
                )
            for entry in chain:
                if entry.startswith("cursor/"):
                    with self.subTest(cursor_id=entry, role=role):
                        self.assertIn(entry, seqeratop_cursor_ids)

    def test_seqeratop_pi_prefers_openai_then_cursor(self) -> None:
        models_result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                ".#darwinConfigurations.Seqeratop.config.modules.agents.pi.enabledModels",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(models_result.returncode, 0, models_result.stderr)
        models = json.loads(models_result.stdout)
        self.assertEqual(
            models[:3],
            [
                "openai-codex/gpt-5.6-sol",
                "openai-codex/gpt-5.6-terra",
                "openai-codex/gpt-5.6-luna",
            ],
        )
        self.assertIn("cursor/cursor-grok-4.6-medium", models)
        self.assertIn("cursor/cursor-grok-4.6-xhigh", models)
        self.assertIn("cursor/composer-2.5-fast", models)
        self.assertIn("cursor/kimi-k3-high", models)

        vars_result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                ".#darwinConfigurations.Seqeratop.config.home-manager.users.edmundmiller.home.sessionVariables",
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(vars_result.returncode, 0, vars_result.stderr)
        session_vars = json.loads(vars_result.stdout)
        self.assertEqual(
            session_vars["PI_MODEL_SWITCH_INTENT"],
            "openai-codex/gpt-5.6-terra",
        )
        self.assertEqual(
            session_vars["PI_MODEL_SWITCH_CODING"],
            "openai-codex/gpt-5.6-sol",
        )
        self.assertEqual(
            session_vars["PI_MODEL_SWITCH_DONE"],
            "openai-codex/gpt-5.6-luna",
        )

    def test_seqeratop_watchdog_uses_one_role_resolved_advisor(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--raw",
                '.#darwinConfigurations.Seqeratop.config.home-manager.users.edmundmiller.home.file.".omp/agent/WATCHDOG.yml".text',
                "--no-write-lock-file",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "advisors:\n  - name: Sol\n")


if __name__ == "__main__":
    unittest.main()
