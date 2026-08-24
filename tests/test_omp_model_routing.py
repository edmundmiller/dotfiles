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

        # Tier 1: every primary role is the same VibeProxy Opus 5 id, varying
        # only thinking level. Same-model prewalk (see model-roles.md).
        self.assertEqual(omp["smolModel"], "vibeproxy/claude-opus-5:low")
        self.assertEqual(omp["modelRoles"]["smol"], "vibeproxy/claude-opus-5:low")
        self.assertEqual(omp["modelRoles"]["default"], "vibeproxy/claude-opus-5:medium")
        self.assertEqual(omp["modelRoles"]["plan"], "vibeproxy/claude-opus-5:high")
        self.assertEqual(omp["modelRoles"]["advisor"], "vibeproxy/claude-opus-5:high")
        self.assertEqual(omp["modelRoles"]["designer"], "vibeproxy/claude-opus-5:high")
        self.assertEqual(omp["modelRoles"]["slow"], "vibeproxy/claude-opus-5:xhigh")

        # Three roles step off Opus deliberately. Haiku carries no :level
        # because models.yml does not declare reasoning for it.
        self.assertEqual(omp["modelRoles"]["task"], "vibeproxy/claude-sonnet-5:xhigh")
        self.assertEqual(
            omp["modelRoles"]["commit"],
            "vibeproxy/claude-haiku-4-5-20251001",
        )
        self.assertEqual(omp["modelRoles"]["tiny"], "openai-codex/gpt-5.6-luna:low")

        # Vision is a deliberate specialist pick, outside the three-tier order.
        self.assertEqual(
            omp["modelRoles"]["vision"],
            "google-antigravity/gemini-3.5-flash",
        )

        # Tier 2 then tier 3: openai-codex hops, Cursor Grok as the last resort.
        self.assertEqual(
            omp["retry"]["fallbackChains"]["default"],
            [
                "openai-codex/gpt-5.6-sol:medium",
                "openai-codex/gpt-5.6-luna:medium",
                "cursor/cursor-grok-4.6-medium",
            ],
        )
        for role in ("plan", "advisor", "designer"):
            with self.subTest(role=role):
                self.assertEqual(
                    omp["retry"]["fallbackChains"][role],
                    [
                        "openai-codex/gpt-5.6-sol:high",
                        "openai-codex/gpt-5.6-luna:high",
                        "cursor/cursor-grok-4.6-high",
                    ],
                )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["task"],
            [
                "openai-codex/gpt-5.6-luna:xhigh",
                "cursor/cursor-grok-4.6-xhigh",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["slow"],
            [
                "openai-codex/gpt-5.6-sol:xhigh",
                "openai-codex/gpt-5.6-terra:high",
                "openai-codex/gpt-5.6-luna:high",
                "cursor/cursor-grok-4.6-xhigh",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["smol"],
            [
                "openai-codex/gpt-5.6-sol:low",
                "openai-codex/gpt-5.6-luna:low",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )
        self.assertEqual(
            omp["retry"]["fallbackChains"]["commit"],
            [
                "openai-codex/gpt-5.6-luna:low",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )
        # tiny's primary is already Luna, so it falls to Sol instead.
        self.assertEqual(
            omp["retry"]["fallbackChains"]["tiny"],
            [
                "openai-codex/gpt-5.6-sol:low",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )

        # Vision fallbacks need images=yes, which rules out every cursor-grok id.
        self.assertEqual(
            omp["retry"]["fallbackChains"]["vision"],
            [
                "vibeproxy/claude-opus-5:medium",
                "openai-codex/gpt-5.6-sol:medium",
                "cursor/gemini-3.5-flash",
            ],
        )

        self.assertEqual(
            omp["dailyIntrospection"]["model"],
            "openai-codex/gpt-5.6-sol:high",
        )
        self.assertEqual(
            omp["modelProviderOrder"][:3],
            ["vibeproxy", "openai-codex", "cursor"],
        )

        seqeratop_cursor_ids = {
            "cursor/cursor-grok-4.6-medium",
            "cursor/cursor-grok-4.6-high",
            "cursor/cursor-grok-4.6-xhigh",
            "cursor/cursor-grok-4.6-low-fast",
            "cursor/gemini-3.5-flash",
        }
        for role, chain in omp["retry"]["fallbackChains"].items():
            with self.subTest(no_composer_or_kimi=role):
                self.assertTrue(
                    all(
                        "composer-2.5" not in entry and "kimi-k3" not in entry
                        for entry in chain
                    ),
                    chain,
                )
            # Cursor is the last-resort net: it terminates every chain and
            # never appears before an openai-codex hop.
            with self.subTest(cursor_is_terminal=role):
                self.assertTrue(chain[-1].startswith("cursor/"), chain)
                self.assertTrue(
                    all(not entry.startswith("cursor/") for entry in chain[:-1]),
                    chain,
                )
            for entry in chain:
                if entry.startswith("cursor/"):
                    with self.subTest(cursor_id=entry, role=role):
                        self.assertIn(entry, seqeratop_cursor_ids)

    def test_seqeratop_vibeproxy_ids_are_declared_in_models_yml(self) -> None:
        """VibeProxy has no model auto-discovery, so every id must be declared.

        See modules/agents/omp/docs/advisor-watchdog.md.
        """
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

        selectors = list(omp["modelRoles"].values())
        selectors.append(omp["smolModel"])
        for chain in omp["retry"]["fallbackChains"].values():
            selectors.extend(chain)

        models_yml = (ROOT / "config" / "omp" / "models.yml").read_text()
        declared = {
            line.split("- id:", 1)[1].strip()
            for line in models_yml.splitlines()
            if line.strip().startswith("- id:")
        }
        self.assertIn("claude-opus-5", declared)

        # VibeProxy reports minimal/low/medium/high/xhigh -- there is no :max.
        supported_levels = {"minimal", "low", "medium", "high", "xhigh"}
        for selector in selectors:
            if not selector.startswith("vibeproxy/"):
                continue
            with self.subTest(selector=selector):
                model = selector.split("/", 1)[1]
                if ":" in model:
                    model, level = model.split(":", 1)
                    self.assertIn(level, supported_levels)
                self.assertIn(model, declared)

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
        self.assertEqual(
            models,
            [
                "openai-codex/gpt-5.6-sol",
                "openai-codex/gpt-5.6-terra",
                "openai-codex/gpt-5.6-luna",
                "cursor/cursor-grok-4.6-medium",
                "cursor/cursor-grok-4.6-high",
                "cursor/cursor-grok-4.6-xhigh",
                "cursor/cursor-grok-4.6-low-fast",
            ],
        )
        self.assertNotIn("cursor/composer-2.5", models)
        self.assertNotIn("cursor/composer-2.5-fast", models)
        self.assertNotIn("cursor/kimi-k3-high", models)

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
        self.assertEqual(result.stdout, "advisors:\n  - name: Opus\n")


if __name__ == "__main__":
    unittest.main()
