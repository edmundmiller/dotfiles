"""Run Bend task implementations against disposable process boundaries."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey task build ")
        cls.addClassCleanup(cls.build.cleanup)
        cls.binary = Path(cls.build.name) / "hey-task"
        subprocess.run(
            ["bash", str(SOURCE / "build"), str(cls.binary), "/unused/mise", "task-main.bend"],
            check=True,
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey native project ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "flake.nix").write_text("{}\n")
        (self.root / "skills").mkdir()
        self.nested = self.root / "nested"
        self.nested.mkdir()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.log = self.root / "operations.jsonl"
        self.env = os.environ | {
            "PATH": f"{self.tools}{os.pathsep}{os.environ['PATH']}",
            "MISE_PROJECT_ROOT": str(self.root),
            "FLAKE_DIR": "/wrong-checkout",
            "FLAKE_HOST": "fixture-host",
            "HEY_TEST_LOG": str(self.log),
        }
        for name in ("nix", "mise", "agent-run", "ssh", "systemctl", "nix-store"):
            path = self.tools / name
            path.write_text(
                f"#!{sys.executable}\n"
                "import json, os, pathlib, sys\n"
                "with open(os.environ['HEY_TEST_LOG'], 'a') as log:\n"
                "    log.write(json.dumps([pathlib.Path(sys.argv[0]).name, sys.argv[1:], os.getcwd()]) + '\\n')\n"
                "if os.environ.get('HEY_TEST_FAIL_ARG') in sys.argv[1:]: sys.exit(23)\n"
                "sys.exit(int(os.environ.get('HEY_TEST_EXIT', '0')))\n"
            )
            path.chmod(0o755)

    def run_task(self, *args):
        return subprocess.run(
            [self.binary, *args], cwd=self.nested, env=self.env,
            capture_output=True, text=True, timeout=10,
        )

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_search_forwards_one_literal_query_and_propagates_failure(self):
        self.env["HEY_TEST_EXIT"] = "37"
        query = "é a b; $(false)"
        result = self.run_task("search", query)
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertEqual(self.operations(), [["nix", ["search", "nixpkgs", query], str(self.nested)]])

    def test_invalid_arguments_fail_before_any_command(self):
        for args in (("search",), ("search", "one", "two"), ("show", "unexpected"), ("unas:recover", "/root")):
            with self.subTest(args=args):
                result = self.run_task(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("invalid task arguments", result.stderr)
                self.assertEqual(self.operations(), [])

    def test_project_operations_use_selected_checkout_not_caller_or_stale_variable(self):
        result = self.run_task("show")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["nix", ["flake", "show"], str(self.root)]])

    def test_context_finds_checkout_without_mise(self):
        self.env.pop("MISE_PROJECT_ROOT")
        result = self.run_task("show")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["nix", ["flake", "show"], str(self.root)]])

    def test_update_inputs_stop_at_first_failure(self):
        self.env["HEY_TEST_FAIL_ARG"] = "second"
        result = self.run_task("update", "first", "second", "never")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.operations(), [
            ["nix", ["flake", "update", "first"], str(self.root)],
            ["nix", ["flake", "update", "second"], str(self.root)],
        ])

    def test_update_without_inputs_updates_once(self):
        result = self.run_task("update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["nix", ["flake", "update"], str(self.root)]])

    def test_pi_update_uses_selected_checkout_and_stops_before_rebuild_on_failure(self):
        self.env["HEY_TEST_FAIL_ARG"] = "1.5.0"
        result = self.run_task("pi:update", "1.5.0")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.operations(), [[
            "nix", ["run", f"{self.root}#pi.updater", "--", f"{self.root}/overlays/pi", "1.5.0"], str(self.nested)
        ]])
        self.log.unlink()
        self.env.pop("HEY_TEST_FAIL_ARG")
        result = self.run_task("pi:update", "1.5.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[-1], ["mise", ["--cd", str(self.root), "run", "rebuild"], str(self.nested)])

    def test_upgrade_does_not_rebuild_after_update_failure(self):
        self.env["HEY_TEST_FAIL_ARG"] = "update"
        result = self.run_task("upgrade")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.operations(), [["mise", ["run", "update"], str(self.nested)]])

    def test_skills_bump_updates_child_then_parent_then_rebuilds(self):
        result = self.run_task("skills:bump")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [
            ["nix", ["flake", "update"], str(self.root / "skills")],
            ["nix", ["flake", "update", "skills-catalog"], str(self.root)],
            ["mise", ["run", "rebuild"], str(self.root)],
        ])

    def test_agent_task_preserves_empty_and_literal_arguments(self):
        result = self.run_task("agent:start", "", "a b", "$(false)", "é", "�", "𝒜")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["agent-run", ["start", "", "a b", "$(false)", "é", "�", "𝒜"], str(self.nested)]])

    def test_invalid_utf8_arguments_fail_before_task_execution(self):
        for invalid in (b"\xff", b"\xc0\xaf", b"\xed\xa0\x80", b"\xf4\x90\x80\x80", b"\xe2\x82"):
            with self.subTest(invalid=invalid):
                result = subprocess.run(
                    [self.binary, "agent:start", invalid], cwd=self.nested, env=self.env,
                    capture_output=True, timeout=10,
                )
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn(b"UTF-8", result.stderr)
                self.assertEqual(self.operations(), [])

    def test_invalid_home_cannot_redirect_cleanup_to_a_replacement_character_path(self):
        decoded_home = self.root / "home�"
        marker = decoded_home / ".cache/opencode/node_modules/keep"
        marker.parent.mkdir(parents=True)
        marker.write_text("must not be removed")
        self.env["HOME"] = os.fsdecode(os.fsencode(self.root) + b"/home\xff")
        result = self.run_task("opencode:update")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("HOME", result.stderr)
        self.assertIn("UTF-8", result.stderr)
        self.assertEqual(marker.read_text(), "must not be removed")

    def test_long_root_reference_reaches_the_command_boundary_without_crashing(self):
        root = str(self.root) + "/" + "d" * 6000
        self.env["MISE_PROJECT_ROOT"] = root
        self.env["HEY_TEST_FAIL_ARG"] = "1.5.0"
        result = self.run_task("pi:update", "1.5.0")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.operations(), [[
            "nix", ["run", root + "#pi.updater", "--", root + "/overlays/pi", "1.5.0"], str(self.nested)
        ]])

    def test_help_does_not_execute_tasks(self):
        for name in ("search", "show", "update", "skills:bump", "agent:start", "unas:recover", "nuc:rollback"):
            with self.subTest(name=name):
                result = self.run_task(name, "--help")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"hey {name}", result.stdout)
                self.assertIn("Parameters:", result.stdout)
                self.assertEqual(self.operations(), [])

    def test_remote_service_name_survives_shell_parsing_without_injection(self):
        marker = self.root / "must-not-exist"
        service = f"service; touch {marker}; echo 'literal' $(false)"
        result = self.run_task("nuc:service", service)
        self.assertEqual(result.returncode, 0, result.stderr)
        command = self.operations()[0][1][-1]
        result = subprocess.run(
            ["bash", "-c", command], cwd=self.root, env=self.env, capture_output=True, timeout=10
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[-1], ["systemctl", ["status", service], str(self.root)])
        self.assertFalse(marker.exists())

    def test_log_count_is_validated_before_ssh(self):
        result = self.run_task("nuc:logs", "service", "not-a-count")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.operations(), [])
        result = self.run_task("nuc:logs", "service", "17")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[0][1], ["nuc", "sudo journalctl -u 'service' -n 17"])

    def test_dry_deploy_routes_nuc_through_guarded_task(self):
        result = self.run_task("deploy:dry", "nuc")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["mise", ["run", "nuc", "--", "dry-activate"], str(self.nested)]])

    def test_keep_generations_never_deletes_profiles(self):
        result = self.run_task("gc", "--keep-generations")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [["nix-store", ["--gc"], str(self.nested)]])

    def test_opencode_cleanup_is_limited_to_its_plugin_cache(self):
        home = self.root / "home"
        cache = home / ".cache/opencode"
        (cache / "node_modules").mkdir(parents=True)
        (cache / "node_modules/plugin").write_text("disposable")
        (cache / "bun.lock").write_text("disposable")
        (cache / "keep").write_text("keep")
        self.env["HOME"] = str(home)
        result = self.run_task("opencode:update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((cache / "node_modules").exists())
        self.assertFalse((cache / "bun.lock").exists())
        self.assertEqual((cache / "keep").read_text(), "keep")

    def test_baseline_reads_the_selected_host_file(self):
        directory = self.root / "benchmarks/zsh-bench"
        directory.mkdir(parents=True)
        data = '{"host":"fixture-host","latency":12}\n'
        (directory / "fixture-host.json").write_text(data)
        result = self.run_task("zbench:baseline")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, data)
        self.assertEqual(self.operations(), [])


if __name__ == "__main__":
    unittest.main()
