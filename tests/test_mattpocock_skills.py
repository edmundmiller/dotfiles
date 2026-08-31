import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "skills/flake.nix"
MANIFEST = ROOT / "skills/mattpocock-skills.json"

EXPECTED_SKILLS = {
    "ask-matt": "engineering/ask-matt",
    "code-review": "engineering/code-review",
    "codebase-design": "engineering/codebase-design",
    "diagnosing-bugs": "engineering/diagnosing-bugs",
    "domain-modeling": "engineering/domain-modeling",
    "grill-me": "productivity/grill-me",
    "grill-with-docs": "engineering/grill-with-docs",
    "grilling": "productivity/grilling",
    "handoff": "productivity/handoff",
    "implement": "engineering/implement",
    "improve-codebase-architecture": "engineering/improve-codebase-architecture",
    "prototype": "engineering/prototype",
    "research": "engineering/research",
    "resolving-merge-conflicts": "engineering/resolving-merge-conflicts",
    "setup-matt-pocock-skills": "engineering/setup-matt-pocock-skills",
    "tdd": "engineering/tdd",
    "teach": "productivity/teach",
    "to-questionnaire": "productivity/to-questionnaire",
    "to-spec": "engineering/to-spec",
    "to-tickets": "engineering/to-tickets",
    "triage": "engineering/triage",
    "wait-what": "productivity/wait-what",
    "wayfinder": "engineering/wayfinder",
    "wizard": "engineering/wizard",
    "writing-for-agents": "productivity/writing-for-agents",
}


class MattPocockSkillsTest(unittest.TestCase):
    def test_curated_manifest_matches_agents_workspace_selection(self) -> None:
        self.assertEqual(EXPECTED_SKILLS, json.loads(MANIFEST.read_text()))

    def test_flake_routes_manifest_to_shared_agents_bundle(self) -> None:
        flake = FLAKE.read_text()
        mattpocock_block = flake[
            flake.index("        mattpocockSkillPaths =") : flake.index(
                "        }) mattpocockSkillPaths;"
            )
        ]

        for declaration in (
            "mattpocock-skills = {",
            'url = "github:mattpocock/skills/5b15a47f2d7150f545fbcacbfe381787fc0230dc";',
            "mattpocockSkillPaths = builtins.fromJSON",
            'from = "mattpocock";',
            'meta.targets = [ "agents" ];',
            'lib.hasPrefix "disable-model-invocation:" line',
            'lib.hasPrefix "argument-hint:" line',
            '"](link)"',
            '"](https://tracker.example/ticket)"',
        ):
            with self.subTest(declaration=declaration):
                self.assertIn(declaration, flake)

        self.assertNotIn('meta.targets = [ "codex" ];', mattpocock_block)

    def test_runtime_overlay_preserves_native_capabilities(self) -> None:
        flake = FLAKE.read_text()
        normalized_flake = " ".join(flake.split())

        for phrase in (
            "Runtime capability routing",
            "Treat `/skill-name` references as references to the named skill",
            "Amp: call the `skill` tool",
            "OMP: read `skill://<name>`",
            "Pi: use `read` on the skill path",
            "OMP: use `ask`",
            "Pi: use `ask_user`",
            "Codex: use `request_user_input`",
            "Amp: use `Task`",
            "OMP: use `task`",
            "Pi has no baseline subagent surface",
            "execute the work inline and sequentially",
            "hand the workflow to OMP when delegation is required",
            "Codex: use `spawn_agent`, `wait_agent`, `interrupt_agent`, and `list_agents`",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, normalized_flake)

        self.assertNotIn("Pi: use `subagent`", normalized_flake)
        self.assertNotIn("`close_agent`", normalized_flake)


if __name__ == "__main__":
    unittest.main()
