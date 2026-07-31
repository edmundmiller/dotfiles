from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills" / "conditional" / "herdr" / "herdr"


def test_herdr_skill_uses_current_agent_and_wait_commands() -> None:
    paths = [
        SKILL / "SKILL.md",
        SKILL / "references" / "cli-map.md",
        SKILL / "references" / "recipes.md",
        SKILL / "references" / "pi-workspace.md",
        SKILL / "scripts" / "monitor_pane.py",
        SKILL / "scripts" / "send_prompt_to_pane.py",
        SKILL / "scripts" / "start_pi_workspace.py",
    ]
    content = "\n".join(path.read_text() for path in paths)

    for legacy in ("agent send ", "wait agent-status", "wait output", "--status"):
        assert legacy not in content

    for current in (
        "agent prompt",
        "agent send-keys",
        "agent wait",
        "pane wait-output",
        "--until",
        "--kind",
        "--pane",
    ):
        assert current in content
