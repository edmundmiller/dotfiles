import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MODULE = ROOT / "modules" / "agents" / "claude" / "default.nix"
AGENTO11Y_HOST = ROOT / "hosts" / "seqeratop" / "agento11y.nix"


class ClaudeActivationTests(unittest.TestCase):
    def test_mcp_cleanup_uses_static_script_instead_of_heredoc(self) -> None:
        module = CLAUDE_MODULE.read_text()
        start = module.index("home.activation.claude-mcp-cleanup")
        opening = module.index("''", start)
        block = module[start : module.index("''", opening + 2)]

        self.assertIn(
            "${pkgs.python3}/bin/python3 ${./claude-mcp-cleanup.py}",
            block,
        )
        self.assertNotIn("<<'PY'", block)

    def test_seqeratop_enables_agento11y_after_install(self) -> None:
        module = AGENTO11Y_HOST.read_text()
        install = module.index("agento11y claude install --json")
        enable = module.index(
            "claude plugin enable \\\n                agento11y-claude-code@agento11y",
            install,
        )
        self.assertLess(install, enable)
        self.assertIn(
            "ERROR: failed to enable Claude Code plugin agento11y-claude-code@agento11y",
            module[enable:],
        )
        self.assertNotIn("install after that rewrite or every", module)


if __name__ == "__main__":
    unittest.main()
