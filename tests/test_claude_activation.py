import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MODULE = ROOT / "modules" / "agents" / "claude" / "default.nix"


class ClaudeActivationTests(unittest.TestCase):
    def test_mcp_cleanup_uses_static_script_instead_of_heredoc(self) -> None:
        module = CLAUDE_MODULE.read_text()
        start = module.index("home.activation.claude-mcp-cleanup")
        block = module[start : module.index("'';", start)]

        self.assertIn(
            "${pkgs.python3}/bin/python3 ${./claude-mcp-cleanup.py}",
            block,
        )
        self.assertNotIn("<<'PY'", block)


if __name__ == "__main__":
    unittest.main()
