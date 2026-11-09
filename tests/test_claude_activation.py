import json
import os
import shutil
import subprocess
import tempfile
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

    def test_agento11y_plugin_enable_is_idempotent_and_reports_failures(self) -> None:
        module = AGENTO11Y_HOST.read_text()
        install = module.index("agento11y claude install --json")
        start = module.index("              if !", install)
        end = module.index("${pkgs.my.agento11y}/bin/agento11y agents reconcile", start)
        block = module[start:end]
        jq = shutil.which("jq")
        self.assertIsNotNone(jq, "jq is required to exercise activation")
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".claude").mkdir()
            settings = home / ".claude/settings.json"
            claude = home / "claude"
            claude.write_text(
                '#!/bin/sh\n'
                'set -eu\n'
                'test "$1 $2" = "plugin enable"\n'
                'if [ "${FAIL_ENABLE:-0}" = 1 ]; then exit 2; fi\n'
                'if grep -q true "$HOME/.claude/settings.json"; then\n'
                '  echo "Plugin is already enabled" >&2; exit 1\n'
                'fi\n'
                'printf \'%s\\n\' \'{"enabledPlugins":{"agento11y-claude-code@agento11y":true}}\' > "$HOME/.claude/settings.json"\n'
            )
            claude.chmod(0o755)
            block = block.replace("${pkgs.llm-agents.claude-code}/bin/claude", str(claude))
            block = block.replace("${pkgs.jq}/bin/jq", jq)
            for enabled, fail, expected_status in [(True, False, 0), (False, False, 0), (False, True, 1)]:
                with self.subTest(enabled=enabled, fail=fail):
                    settings.write_text(json.dumps({"enabledPlugins": {"agento11y-claude-code@agento11y": enabled}}))
                    result = subprocess.run(
                        ["bash", "-eu", "-c", block],
                        env={**os.environ, "HOME": directory, "FAIL_ENABLE": str(int(fail))},
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, expected_status, result.stderr)
                    self.assertEqual(
                        json.loads(settings.read_text())["enabledPlugins"]["agento11y-claude-code@agento11y"],
                        not fail,
                    )

    def test_agento11y_injection_failure_keeps_credentials_and_continues(self) -> None:
        module = AGENTO11Y_HOST.read_text()
        start = module.index('config_dir="$HOME/.config/agento11y"')
        end = module.index("${pkgs.llm-agents.codex}/bin/codex plugin marketplace add", start)
        block = module[start:end] + 'echo continued\n'
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            op = home / "op"
            op.write_text(
                '#!/bin/sh\n'
                'set -eu\n'
                'if [ "${FAIL_INJECT:-0}" = 1 ]; then\n'
                '  echo "error initializing client: authorization timeout" >&2; exit 1\n'
                'fi\n'
                'while [ "$1" != --out-file ]; do shift; done\n'
                'echo fresh > "$2"\n'
            )
            op.chmod(0o755)
            block = block.replace("${pkgs._1password-cli}/bin/op", str(op))
            block = block.replace("${../../config/agento11y/config.env.tpl}", "/dev/null")
            config = home / ".config/agento11y/config.env"
            for existing, fail, expected, warning in [
                (None, False, "fresh\n", None),
                ("stale\n", True, "stale\n", "keeping existing"),
                (None, True, None, "no credentials"),
            ]:
                with self.subTest(existing=existing, fail=fail):
                    if config.exists():
                        config.unlink()
                    if existing is not None:
                        config.parent.mkdir(parents=True, exist_ok=True)
                        config.write_text(existing)
                    result = subprocess.run(
                        ["bash", "-c", f"(\nset -eu\n{block})"],
                        env={**os.environ, "HOME": directory, "FAIL_INJECT": str(int(fail))},
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "continued\n")
                    if expected is None:
                        self.assertFalse(config.exists())
                    else:
                        self.assertEqual(config.read_text(), expected)
                    if warning is None:
                        self.assertNotIn("WARNING", result.stderr)
                    else:
                        self.assertIn(warning, result.stderr)
                    self.assertEqual(list(config.parent.glob("config.env.*")), [])

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
