"""Validation routing and isolation, with real disposable Git repositories."""

import contextlib
import io
import json
import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import validation as v


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        v.git(self.root, "init", "--quiet")
        v.git(self.root, "config", "user.name", "Fixture")
        v.git(self.root, "config", "user.email", "fixture@example.invalid")
        v.git(self.root, "config", "commit.gpgsign", "false")
        v.git(self.root, "config", "core.hooksPath", "/dev/null")
        self.write("tracked.md", "base\n")
        self.commit()
        v.git(self.root, "update-ref", "refs/remotes/origin/main", "HEAD")

    def write(self, name, content):
        file = self.root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)
        return file

    def commit(self):
        v.git(self.root, "add", "--all")
        v.git(self.root, "commit", "--no-gpg-sign", "--quiet", "-m", "fixture")

    def invoke(self, *args):
        output, errors = io.StringIO(), io.StringIO()
        with (
            patch.object(v, "ROOT", self.root),
            contextlib.redirect_stdout(output),
            contextlib.redirect_stderr(errors),
        ):
            code = v.main(list(args))
        return code, output.getvalue(), errors.getvalue()

    def selection(self, *args):
        code, output, error = self.invoke("--plan", *args)
        self.assertEqual(code, 0, error)
        return json.loads(output)

    def package(self, name, deps=None):
        return self.write(
            f"packages/pi-packages/{name}/package.json",
            json.dumps(
                {
                    "name": "@test/" + name,
                    "dependencies": deps or {},
                    "scripts": {"typecheck": "tsc", "test": "bun test"},
                }
            ),
        )

    def test_default_unions_branch_staged_unstaged_untracked_and_deletions(self):
        self.write("committed.md", "branch\n")
        self.commit()
        # A feature's own upstream must not hide its committed work.
        v.git(self.root, "update-ref", "refs/remotes/origin/feature", "HEAD")
        branch = v.git(self.root, "branch", "--show-current").stdout.decode().strip()
        v.git(self.root, "config", f"branch.{branch}.remote", "origin")
        v.git(self.root, "config", f"branch.{branch}.merge", "refs/heads/feature")
        self.write("staged.md", "staged\n")
        v.git(self.root, "add", "staged.md")
        self.write("committed.md", "dirty\n")
        self.write("space and\nnewline.md", "untracked\n")
        (self.root / "tracked.md").unlink()
        self.assertEqual(
            self.selection()["files"],
            ["committed.md", "space and\nnewline.md", "staged.md", "tracked.md"],
        )

    def test_rename_selects_old_and_new_owner(self):
        self.write("config/tmux/old", "move\n")
        self.commit()
        v.git(self.root, "update-ref", "refs/remotes/origin/main", "HEAD")
        v.git(self.root, "mv", "config/tmux/old", "new")
        selected = self.selection()
        self.assertEqual(selected["files"], ["config/tmux/old", "new"])
        self.assertIn("zunit-tests", selected["checks"])

    def test_hunk_changes_select_runtime_config_compatibility(self):
        patterns = v.CHECKS["hunk-config-compatibility"]
        for file in (
            "config/hunk/config.toml",
            "modules/shell/git/default.nix",
            "overlays/hunk/package-harness.json",
            "overlays/hunk/patches/example.patch",
        ):
            with self.subTest(file=file):
                self.assertTrue(v.matches([file], patterns))
        self.assertFalse(v.matches(["config/jj/config.toml"], patterns))

        self.write("flake.lock", "changed")
        self.assertIn("hunk-config-compatibility", self.selection()["checks"])

    def test_mcp_sources_select_shared_reconciliation_tests(self):
        for path in (
            "config/agents/mcp.nix",
            "config/agents/reconcile_mcp.py",
            "modules/agents/mcp/default.nix",
            "tests/test_agent_mcp.py",
            "hosts/seqeratop/default.nix",
        ):
            with self.subTest(path=path):
                self.write(path, "changed")
                self.assertIn("agent-mcp-tests", self.selection(path)["checks"])

    def test_ha_changes_select_linux_contract_and_runtime_checks(self):
        checks = {
            "ha-automation-assertions",
            "ha-behavior-tests",
            "ha-robot-cleaning-tests",
        }
        paths = (
            "modules/services/hass/_domains/aranet.nix",
            "modules/services/hass/_tests/test_good_morning.py",
            "hosts/nuc/default.nix",
            "scripts/validation.py",
        )
        with (
            patch.object(v.platform, "system", return_value="Linux"),
            patch.object(v.platform, "machine", return_value="x86_64"),
            patch.dict(os.environ, {"VALIDATION_BASE": "origin/main"}),
        ):
            for path in paths:
                with self.subTest(path=path):
                    self.write(path, "changed")
                    self.assertTrue(checks <= set(self.selection(path)["checks"]))
                    self.assertTrue(checks <= set(self.selection("--ci", path)["checks"]))
            self.write("docs/unrelated.md", "changed")
            self.assertFalse(checks & set(self.selection("docs/unrelated.md")["checks"]))
            self.assertFalse(checks & set(self.selection("--packages-only")["checks"]))
            self.assertTrue(checks <= set(self.selection("--full")["checks"]))

        for system, machine in (("Darwin", "arm64"), ("Linux", "aarch64")):
            with (
                self.subTest(system=system, machine=machine),
                patch.object(v.platform, "system", return_value=system),
                patch.object(v.platform, "machine", return_value=machine),
            ):
                self.assertFalse(checks & set(self.selection(paths[0])["checks"]))
                self.assertFalse(checks & set(self.selection("--full")["checks"]))

    def test_flue_and_repair_changes_select_observability_and_policy(self):
        self.write("renovate.json", "{}")
        selected = self.selection("renovate.json")
        self.assertIn("package-policy-tests", selected["checks"])
        self.assertFalse(selected["flue"])
        for path in (
            ".flue/observability.ts",
            ".flue/tests/observability.test.ts",
            ".flue/package-lock.json",
            "packages/flue-evlog/src/index.ts",
            "packages/flue-evlog/package-lock.json",
            ".github/workflows/renovate-patch-repair.yml",
        ):
            with self.subTest(path=path):
                self.write(path, "changed")
                selected = self.selection(path)
                self.assertTrue(selected["flue"])
                self.assertIn("package-policy-tests", selected["checks"])
        self.write("docs/unrelated.md", "changed")
        self.assertFalse(self.selection("docs/unrelated.md")["flue"])
        self.assertTrue(self.selection("--full")["flue"])
        self.assertFalse(self.selection("--packages-only")["flue"])

    def test_task_scopes_do_not_select_unrelated_dirt_or_prefix_siblings(self):
        self.write("owned/a.md", "yes")
        self.write("owned-other/b.nix", "no")
        self.write("unrelated.md", "no")
        self.write("packages/pi-packages/pi-unrelated/package.json", "unfinished JSON")
        selected = self.selection("./owned/")
        self.assertEqual(selected["files"], ["owned/a.md"])
        self.assertEqual(selected["checks"], [])
        self.assertFalse(selected["packages"])

    def test_invalid_base_fails_not_empty_success(self):
        code, _, error = self.invoke("--base-ref", "missing-ref")
        self.assertEqual(code, 1)
        self.assertIn("missing-ref", error)

    def test_ci_base_matches_local_and_empty_base_escalates(self):
        self.write("docs/edit.md", "edit")
        with patch.dict(os.environ, {"VALIDATION_BASE": "origin/main"}):
            self.assertEqual(
                self.selection("--ci"), self.selection("--base-ref", "origin/main")
            )
        for base in ("", "0" * 40):
            with patch.dict(os.environ, {"VALIDATION_BASE": base}):
                self.assertEqual(self.selection("--ci"), self.selection("--full"))

    def test_ci_platform_routes_both_sides_of_dependency_boundary(self):
        with (
            patch.dict(os.environ, {"VALIDATION_BASE": "origin/main"}),
            patch.object(v.platform, "system", return_value="Linux"),
            patch.object(v.platform, "machine", return_value="x86_64"),
        ):
            self.write("docs/edit.md", "unrelated")
            self.assertIsNone(
                self.selection("--ci", "--platform", "darwin")["platform"]
            )
            self.assertIsNone(
                self.selection("--ci", "--platform", "herdr-vm")["platform"]
            )
            self.write("modules/shell/herdr/default.nix", "affected")
            self.assertEqual(
                self.selection("--ci", "--platform", "herdr-vm")["platform"], "herdr-vm"
            )

    def test_platform_plan_does_not_require_a_native_builder(self):
        self.write("flake.lock", "shared change")
        with patch.dict(os.environ, {"VALIDATION_BASE": "origin/main"}):
            for host, target in (("Darwin", "herdr-vm"), ("Linux", "darwin")):
                with patch.object(v.platform, "system", return_value=host):
                    self.assertEqual(
                        self.selection("--ci", "--platform", target)["platform"], target
                    )

    def test_source_mutation_during_validation_invalidates_success(self):
        self.write("owned.md", "before")

        def concurrent_edit(*_):
            self.write("owned.md", "after")
            return 0

        with patch.object(v, "execute", side_effect=concurrent_edit):
            code, _, error = self.invoke("owned.md")
        self.assertEqual(code, 1)
        self.assertIn("results are stale", error)

    def test_plan_and_empty_scope_run_no_checker_and_create_no_snapshot(self):
        self.write("unrelated.md", "dirty")
        before = v.git(self.root, "diff", "--binary", "HEAD").stdout
        with (
            patch.object(
                v, "snapshot", side_effect=AssertionError("snapshot forbidden")
            ),
            patch.object(v, "execute", side_effect=AssertionError("checker forbidden")),
        ):
            self.selection()
            self.assertEqual(self.invoke("missing")[0], 0)
        self.assertEqual(before, v.git(self.root, "diff", "--binary", "HEAD").stdout)

    def test_read_only_sessions_have_no_automatic_stop_gate(self):
        self.assertFalse(
            json.loads((v.ROOT / ".codex/hooks.json").read_text())["hooks"].get("Stop")
        )
        self.assertFalse((v.ROOT / "scripts/codex-validate-stop").exists())

    def test_full_includes_clean_sources_and_does_not_imply_platform_checks(self):
        self.package("pi-example")
        self.commit()
        selected = self.selection("--full")
        self.assertIn("tracked.md", selected["files"])
        self.assertIn("validation-tests", selected["checks"])
        self.assertIn("agent-instruction-tests", selected["checks"])
        self.assertIn("pi-example", selected["packages"])
        self.assertIsNone(selected["platform"])
        self.assertNotIn("trmnl-agent-message-render", selected["checks"])
        self.assertFalse(
            any("dji" in name or "vm-test" in name for name in selected["checks"])
        )

    def test_unas_vm_checks_are_excluded_from_portable_plans(self):
        vm_checks = {"unas-recovery", "unas-late-bulk"}
        for path in (
            "hosts/nuc/default.nix",
            "hosts/unas/nas.nix",
            "overlays/home-assistant-mcp-schema-compat/default.nix",
            "flake.nix",
        ):
            self.write(path, "changed")
            with self.subTest(path=path):
                self.assertFalse(vm_checks & set(self.selection(path)["checks"]))
        self.assertFalse(vm_checks & set(self.selection("--full")["checks"]))
        self.assertEqual(self.selection("--platform", "nixos")["platform"], "nixos")

    def test_shared_lock_and_tests_only_changes_check_all_packages(self):
        self.package("pi-a")
        self.package("pi-b")
        for file in [
            "packages/pi-packages/bun.lock",
            "packages/pi-packages/tests/example.test.ts",
            "packages/pi-packages/package.json",
        ]:
            with self.subTest(file=file):
                packages, integration = v.package_plan(self.root, [file])
                self.assertEqual(packages, ["pi-a", "pi-b"])
                self.assertTrue(integration)

    def test_transitive_dependents_not_unrelated_packages(self):
        self.package("pi-a")
        self.package("pi-b", {"@test/pi-a": "workspace:*"})
        self.package("pi-c", {"@test/pi-b": "workspace:*"})
        self.package("pi-unrelated")
        packages, integration = v.package_plan(
            self.root, ["packages/pi-packages/pi-a/index.ts"]
        )
        self.assertEqual(packages, ["pi-a", "pi-b", "pi-c"])
        self.assertTrue(integration)

    def test_removed_package_and_unknown_explicit_package(self):
        self.assertEqual(
            v.package_plan(self.root, ["packages/pi-packages/pi-removed/index.ts"])[0],
            [],
        )
        self.package("pi-survivor")
        self.assertEqual(
            v.package_plan(self.root, ["packages/pi-packages/pi-removed/package.json"]),
            (["pi-survivor"], True),
        )
        with self.assertRaisesRegex(ValueError, "Unknown packages"):
            v.package_plan(self.root, [], packages=["pi-typo"])

    def test_platform_rejection_happens_before_checks(self):
        for host, target in (("Darwin", "herdr-vm"), ("Linux", "darwin")):
            with (
                patch.object(v.platform, "system", return_value=host),
                patch.object(
                    v, "execute", side_effect=AssertionError("must not execute")
                ),
                contextlib.redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit) as error,
            ):
                self.invoke("--platform", target)
            self.assertEqual(error.exception.code, 2)

    def test_nixos_platform_reports_flake_check_failure(self):
        commands = []

        def tools(command, **kwargs):
            commands.append(command)
            failure = "flake" in command and "check" in command
            return subprocess.CompletedProcess(command, 1 if failure else 0, stdout="x86_64-linux")

        with (
            patch.object(v.platform, "system", return_value="Linux"),
            patch.object(v.platform, "machine", return_value="x86_64"),
            patch.object(v, "nix_env", return_value={}),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else tools(command, **kw)
                ),
            ),
        ):
            code, _, error = self.invoke("--platform", "nixos")
        self.assertEqual(code, 1)
        self.assertTrue(any("flake" in command and "check" in command for command in commands))
        self.assertIn("full NixOS flake", error)

    def test_darwin_forces_host_derivations_and_builds_native_checks(self):
        commands = []

        def tools(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0, stdout="aarch64-darwin")

        with (
            patch.object(v.platform, "system", return_value="Darwin"),
            patch.object(v.platform, "machine", return_value="arm64"),
            patch.object(v, "nix_env", return_value={}),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else tools(command, **kw)
                ),
            ),
        ):
            code, _, error = self.invoke("--platform", "darwin")
        self.assertEqual(code, 0, error)
        self.assertEqual(
            [command[-1] for command in commands[1:] if "eval" in command],
            [
                ".#darwinConfigurations.MacTraitor-Pro.system.drvPath",
                ".#darwinConfigurations.Seqeratop.system.drvPath",
            ],
        )
        self.assertIn(
            ".#checks.aarch64-darwin.mactraitor-fail-closed-activation",
            [command[-1] for command in commands if "build" in command],
        )
        self.assertIn(
            ".#checks.aarch64-darwin.dji-mic-mini-receiver-mute-regressions",
            [command[-1] for command in commands if "build" in command],
        )
        self.assertIn(
            ".#checks.aarch64-darwin.herdr-app-launch-config",
            [command[-1] for command in commands if "run" in command],
        )

    def test_snapshot_is_unsigned_preserves_source_index_and_internal_links(self):
        self.write("ignored/node_modules/state", "keep")
        self.write("tracked-ignored.toml", "keep\n")
        v.git(self.root, "add", "tracked-ignored.toml")
        self.write(".gitignore", "ignored/\ntracked-ignored.toml\n")
        self.write("tracked.md", "staged")
        v.git(self.root, "add", "tracked.md")
        self.write("tracked.md", "unstaged")
        (self.root / "link").symlink_to("tracked.md")
        (self.root / "dir-link").symlink_to("ignored")
        index = (self.root / ".git/index").read_bytes()
        target = Path(self.temp.name) / "snapshot"
        target.mkdir()
        # Signing is mandatory in the caller; only the disposable repo opts out.
        with patch.dict(
            os.environ,
            {
                "GIT_CONFIG_COUNT": "1",
                "GIT_CONFIG_KEY_0": "commit.gpgsign",
                "GIT_CONFIG_VALUE_0": "true",
            },
        ):
            v.snapshot(self.root, target)
        self.assertEqual(index, (self.root / ".git/index").read_bytes())
        self.assertEqual((target / "tracked.md").read_text(), "unstaged")
        self.assertEqual((target / "tracked-ignored.toml").read_text(), "keep\n")
        self.assertIn(
            b"tracked-ignored.toml",
            v.git(target, "ls-files", "-z").stdout.split(b"\0"),
        )
        self.assertFalse((target / "ignored").exists())
        self.assertEqual(os.readlink(target / "link"), "tracked.md")
        self.assertEqual(
            v.git(target, "log", "-1", "--format=%G?").stdout.strip(), b"N"
        )
        (target / "tracked.md").write_text("formatter mutation")
        self.assertEqual((self.root / "tracked.md").read_text(), "unstaged")

    def test_snapshot_rejects_external_symlinks_without_touching_target(self):
        external = Path(self.temp.name) / "outside"
        external.write_text("precious")
        (self.root / "link").symlink_to(external)
        target = Path(self.temp.name) / "snapshot"
        target.mkdir()
        with self.assertRaisesRegex(ValueError, "External symlink"):
            v.snapshot(self.root, target)
        self.assertEqual(external.read_text(), "precious")

    def test_mutating_formatter_fails_and_preserves_dirty_source(self):
        self.write("owned.md", "bad formatting")
        self.write("unrelated.md", "must not change")

        def tools(command, **kwargs):
            cwd = Path(kwargs["cwd"])
            if command[0] == "prek":
                (cwd / "owned.md").write_text("fixed")
            return subprocess.CompletedProcess(command, 0, stdout="/fake/config\n")

        # Keep real Git; only validator subprocesses are replaced.
        real_git = v.git
        with (
            patch.object(v, "git", side_effect=real_git),
            patch.object(v, "nix_env", return_value={}),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else tools(command, **kw)
                ),
            ),
        ):
            code, _, error = self.invoke("owned.md")
        self.assertEqual(code, 1)
        self.assertIn("source mutation", error)
        self.assertEqual((self.root / "owned.md").read_text(), "bad formatting")
        self.assertEqual((self.root / "unrelated.md").read_text(), "must not change")

    def test_removed_plugin_files_need_no_plugin_linter(self):
        plugin = self.write("config/claude/plugins/retired/README.md", "retired")
        lint_config = self.write(".claudelint.toml", "retired")
        self.commit()
        v.git(self.root, "update-ref", "refs/remotes/origin/main", "HEAD")
        plugin.unlink()
        lint_config.unlink()
        calls = []

        def tools(command, **kwargs):
            calls.append(command[0])
            return subprocess.CompletedProcess(command, 0, stdout="/fake/config\n")

        with (
            patch.object(v, "nix_env", return_value={}),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else tools(command, **kw)
                ),
            ),
        ):
            code, _, error = self.invoke()
        self.assertEqual(code, 0, error)
        self.assertEqual(calls, ["nix"])

    def test_failure_is_not_cached_or_hidden_by_later_success(self):
        self.package("pi-a")
        calls = []

        def tools(command, **kwargs):
            calls.append(command)
            if command[0] == "bun" and command[1] == "run":
                self.assertEqual(kwargs["env"]["GIT_CONFIG_KEY_0"], "commit.gpgsign")
                self.assertEqual(kwargs["env"]["GIT_CONFIG_VALUE_0"], "false")
            return subprocess.CompletedProcess(
                command, 7 if command[-1] == "typecheck" else 0, stdout=""
            )

        for attempt in range(2):
            with (
                patch.object(v, "nix_env", return_value={}),
                patch(
                    "scripts.validation.subprocess.run",
                    side_effect=lambda command, **kw: (
                        subprocess_run(command, **kw)
                        if command[0] == "git"
                        else tools(command, **kw)
                    ),
                ),
            ):
                code, _, error = self.invoke("--packages-only")
            self.assertEqual(code, 1, attempt)
            self.assertIn("pi-a typecheck", error)
        self.assertEqual(sum(c[-1] == "typecheck" for c in calls), 2)
        self.assertTrue(any(c[-1] == "test:integration" for c in calls))

    def test_gh_token_only_reaches_nix_children_not_logs_or_hooks(self):
        self.write("owned.md", "edit")
        children = []

        def tools(command, **kwargs):
            if command[0] == "gh":
                return subprocess.CompletedProcess(
                    command, 0, stdout="fixture-secret\n"
                )
            children.append((command, kwargs.get("env")))
            return subprocess.CompletedProcess(command, 0, stdout="/fake/config\n")

        with (
            patch("scripts.validation.shutil.which", return_value="/fake/gh"),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else tools(command, **kw)
                ),
            ),
        ):
            code, output, error = self.invoke("owned.md")
        self.assertEqual(code, 0, error)
        self.assertNotIn("fixture-secret", output + error)
        for command, env in children:
            if command[0] == "nix":
                self.assertIn("fixture-secret", env["NIX_CONFIG"])
            else:
                self.assertNotIn("fixture-secret", (env or {}).get("NIX_CONFIG", ""))

    def test_explicit_nix_token_is_removed_from_ambient_environment(self):
        observed_tokens = []

        def planned(*_args):
            observed_tokens.append(os.environ.get("NIX_GITHUB_TOKEN"))
            return {
                "files": [],
                "hooks": False,
                "checks": [],
                "packages": [],
                "integration": False,
                "platform": None,
            }

        with (
            patch.dict(os.environ, {"NIX_GITHUB_TOKEN": "fixture-secret"}),
            patch.object(v, "plan", side_effect=planned),
        ):
            code, _, error = self.invoke("--plan")
        self.assertEqual(code, 0, error)
        self.assertEqual(observed_tokens, [None])

        env = v.nix_env("fixture-secret")
        self.assertNotIn("NIX_GITHUB_TOKEN", env)
        self.assertIn("access-tokens = github.com=fixture-secret", env["NIX_CONFIG"])

    def test_missing_checker_is_failure_with_actionable_diagnostic(self):
        self.write("owned.md", "edit")
        with (
            patch.object(v, "nix_env", return_value={}),
            patch(
                "scripts.validation.subprocess.run",
                side_effect=lambda command, **kw: (
                    subprocess_run(command, **kw)
                    if command[0] == "git"
                    else (_ for _ in ()).throw(FileNotFoundError())
                ),
            ),
        ):
            code, _, error = self.invoke("owned.md")
        self.assertEqual(code, 1)
        self.assertIn("missing nix", error)
        self.assertIn("dev shell", error)

    def test_check_file_task_and_direct_ci_entry_select_identical_work(self):
        (self.root / "scripts").mkdir()
        shutil.copy2(
            v.ROOT / "scripts/validation.py", self.root / "scripts/validation.py"
        )
        self.write("owned space.md", "edit")
        env = os.environ | {"MISE_PROJECT_ROOT": str(self.root)}
        result = subprocess.run(
            [
                "bash",
                str(v.ROOT / "bin/hey.d/check"),
                "--plan",
                "owned space.md",
            ],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), self.selection("owned space.md"))

    def test_ci_uses_shared_runner_not_a_second_list(self):
        workflow = (v.ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("python3 scripts/validation.py", workflow)
        self.assertNotIn(".#checks.", workflow)
        self.assertNotIn("qa-changed", workflow)
        self.assertNotIn("--platform darwin", workflow.split("  herdr-vm-test:")[0])
        linux = workflow.split("  checks:")[1].split("  herdr-vm-test:")[0]
        self.assertIn(
            "NIX_GITHUB_TOKEN: ${{ secrets.NIX_PRIVATE_GITHUB_TOKEN }}", linux
        )
        self.assertNotIn("secrets.RENOVATE_TOKEN", linux)
        self.assertNotIn("needs: darwin", linux)
        linux = workflow.split("  checks:")[1].split("  herdr-vm-test:")[0]
        darwin = workflow.split("\n  darwin:\n")[1].split("  vm-services:")[0]
        self.assertIn("runs-on: xcode-27", darwin)
        self.assertIn("if: github.event_name == 'workflow_dispatch' && inputs.darwin", darwin)
        self.assertIn("darwin:\n        description:", workflow)
        self.assertIn("default: false", workflow.split("permissions:")[0])
        for job in (linux, darwin):
            self.assertIn(
                "NIX_GITHUB_TOKEN: ${{ secrets.NIX_PRIVATE_GITHUB_TOKEN }}", job
            )
            self.assertIn('if [[ -z "$NIX_GITHUB_TOKEN" ]]', job)
            self.assertNotIn("secrets.RENOVATE_TOKEN", job)

    def test_darwin_xcode_selection_resolves_image_aliases_and_rejects_missing_app(
        self,
    ):
        workflow = (v.ROOT / ".github/workflows/ci.yml").read_text()
        preparation = textwrap.dedent(
            workflow.split("      - name: Prepare Xcode 27.2 Metal toolchain\n", 1)[1]
            .split("        run: |\n", 1)[1]
            .split("      - ", 1)[0]
        )
        for installed in (True, False):
            with self.subTest(installed=installed):
                applications = self.root.resolve() / str(installed) / "Applications"
                applications.mkdir(parents=True)
                selected = applications / "Xcode_27.2_Release_Candidate.app"
                if installed:
                    (selected / "Contents/Developer").mkdir(parents=True)
                for alias in ("Xcode_27.2.app", "Xcode_27.2.0.app"):
                    (applications / alias).symlink_to(
                        selected, target_is_directory=True
                    )
                command = preparation.replace("/Applications/", f"{applications}/")
                # Observe the app passed to hey without downloading or selecting
                # a real toolchain. Path resolution uses the real fixture aliases.
                commands = (
                    'jq() { printf "fixture-revision"; };\n'
                    'nix() { while [[ "$1" != --command ]]; do shift; done; shift; "$@"; };\n'
                    'env() { if [[ "$1" == MISE_TRUSTED_CONFIG_PATHS=* ]]; then shift; "$@"; fi; };\n'
                    'mise() { [[ "$1 $2" == "run xcode:setup" ]] || return 1; printf "%s\\n" "$3"; };\n'
                )
                result = subprocess.run(
                    ["bash", "-c", commands + command],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, installed, result.stderr)
                self.assertEqual(
                    result.stdout.strip(), str(selected) if installed else ""
                )

    def test_darwin_cleanup_preserves_selected_xcode_and_rejects_invalid_selection(
        self,
    ):
        workflow = (v.ROOT / ".github/workflows/ci.yml").read_text()
        cleanup = textwrap.dedent(
            workflow.split("      - name: Free space for Darwin builds\n", 1)[1]
            .split("        run: |\n", 1)[1]
            .split("      - ", 1)[0]
        )
        for valid_selection in (True, False):
            with self.subTest(valid_selection=valid_selection):
                root = self.root / str(valid_selection)
                applications = root / "installed-apps"
                selected = applications / "Xcode_27.1.app"
                developer = selected / "Contents/Developer"
                developer.mkdir(parents=True)
                sentinel = developer / "keep.txt"
                sentinel.write_text("selected toolchain")
                inactive = applications / "Xcode_27.app"
                inactive.mkdir()
                alias = applications / "Xcode.app"
                alias.symlink_to(selected, target_is_directory=True)
                unrelated = applications / "Other.app"
                unrelated.mkdir()
                command_line_tools = root / "CommandLineTools"
                command_line_tools.mkdir()
                selected_path = (
                    alias / "Contents/Developer"
                    if valid_selection
                    else command_line_tools
                )
                command = cleanup.replace("/Applications/", f"{applications}/")
                self.assertNotIn("/Applications/", command)
                # Only tool discovery and privilege elevation are replaced. The
                # workflow deletes real disposable fixture directories.
                commands = (
                    'xcode-select() { printf "%s\\n" "$SELECTED_DEVELOPER"; };\n'
                    'sudo() { "$@"; };\n'
                    'xcodebuild() { test -d "$SELECTED_DEVELOPER"; };\n'
                )
                result = subprocess.run(
                    ["bash", "-c", commands + command],
                    env=os.environ | {"SELECTED_DEVELOPER": str(selected_path)},
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, valid_selection, result.stderr)
                self.assertEqual(sentinel.read_text(), "selected toolchain")
                self.assertTrue(alias.is_symlink())
                self.assertTrue(unrelated.is_dir())
                self.assertEqual(inactive.exists(), not valid_selection)

    def test_required_ci_contexts_fail_closed(self):
        workflow = (v.ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("  required-checks:", workflow)
        required = workflow.split("  required-checks:")[1].split("  herdr-vm-test:")[0]
        self.assertIn("name: ${{ matrix.context }}", required)
        self.assertIn("context: [Flake Check (Linux), Check Formatting]", required)
        self.assertIn("needs: [plan, checks, herdr-vm-test, darwin, vm-services]", required)
        self.assertIn("if: always()", required)
        command = textwrap.dedent(required.split("run: |\n", 1)[1])
        baseline = {
            "PLAN_RESULT": "success", "LINUX_RESULT": "success",
            "HERDR_REQUIRED": "false", "HERDR_RESULT": "skipped",
            "DARWIN_REQUIRED": "false", "DARWIN_RESULT": "skipped",
            "SERVICES_REQUIRED": "false", "SERVICES_RESULT": "skipped",
        }
        cases = [(baseline, True)]
        for job in ("PLAN", "LINUX"):
            for result in ("failure", "cancelled", "skipped", ""):
                cases.append((baseline | {job + "_RESULT": result}, False))
        for job in ("HERDR", "DARWIN", "SERVICES"):
            for requested in ("true", "false", ""):
                for result in ("success", "failure", "cancelled", "skipped", ""):
                    expected = (requested, result) in (("true", "success"), ("false", "skipped"))
                    cases.append((baseline | {job + "_REQUIRED": requested, job + "_RESULT": result}, expected))
        for environment, expected in cases:
            with self.subTest(environment=environment):
                completed = subprocess.run(
                    ["bash", "-euc", command],
                    env=os.environ | environment,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(completed.returncode == 0, expected, completed.stderr)


class TypeScriptArchitectureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.script = self.root / "bin/lint-ts-architecture"
        self.script.parent.mkdir()
        shutil.copyfile(v.ROOT / "bin/lint-ts-architecture", self.script)
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.bash = shutil.which("bash")
        self.rg = shutil.which("rg")
        self.assertIsNotNone(self.rg, "architecture tests require ripgrep")
        (self.tools / "rg").symlink_to(self.rg)
        self.source = "packages/pi-packages/pi-fixture/index.ts"
        source = self.root / self.source
        source.parent.mkdir(parents=True)
        source.write_text("const count: number = 1;\n")

    def run_gate(self, *paths):
        return subprocess.run(
            [self.bash, self.script, *paths],
            env=os.environ | {"PATH": str(self.tools)},
            capture_output=True,
            text=True,
            timeout=5,
        )

    def test_scans_real_sources_and_reports_tool_and_count(self):
        version = subprocess.check_output([self.rg, "--version"], text=True).splitlines()[0]
        for source, status, diagnostic in (
            ("const count: number = 1;\n", 0, "TS architecture lint passed"),
            ("const count = input as any;\n", 1, "'as any' is forbidden"),
            ('import other from "../pi-other/index";\n', 1, "cross-package relative import"),
        ):
            with self.subTest(source=source):
                (self.root / self.source).write_text(source)
                result = self.run_gate(self.source)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertIn(diagnostic, result.stdout + result.stderr)
                self.assertIn(str(self.tools / "rg"), result.stdout)
                self.assertIn(version, result.stdout)
                self.assertIn("scanned 1 TypeScript files", result.stdout + result.stderr)

    def test_missing_rg_is_not_a_clean_scan(self):
        (self.tools / "rg").unlink()
        result = self.run_gate(self.source)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("requires rg", result.stderr)
        self.assertIn("nix shell .#validation-tools", result.stderr)
        self.assertNotIn("lint passed", result.stdout)

    def test_scan_error_is_not_a_clean_scan(self):
        (self.tools / "rg").unlink()
        command = self.tools / "rg"
        command.write_text(
            f'#!{self.bash}\n'
            f'if [[ "$1" == --version ]]; then exec "{self.rg}" --version; fi\n'
            'printf "fixture scan error\\n" >&2\nexit 2\n'
        )
        command.chmod(0o755)
        result = self.run_gate(self.source)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("scan failed", result.stderr)
        self.assertIn("fixture scan error", result.stderr)
        self.assertNotIn("lint passed", result.stdout)


class NucDeploymentWorkflowTests(unittest.TestCase):
    def test_dispatch_rejects_a_different_revision_before_deployment(self):
        workflow = (v.ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        self.assertIn("EXPECTED_SHA: ${{ inputs.expected_sha }}", workflow)
        self.assertIn("DEPLOY_SHA: ${{ github.sha }}", workflow)
        self.assertLess(workflow.index("        run: |"), workflow.index("- uses:"))
        # Execute the first shell gate, before any checkout or tailnet enrollment.
        gate = textwrap.dedent(
            workflow.split("        run: |\n", 1)[1].split("      - ", 1)[0]
        )
        captured_sha = "0123456789abcdef0123456789abcdef01234567"
        # Successful GitHub responses let the old CI-only gate accept the race.
        # These functions also keep a regression from contacting real GitHub.
        github = 'gh() { printf "%s\\n" "$DEPLOY_SHA"; }; jq() { return 0; };\n'
        for expected_sha, accepted in (
            (captured_sha, True),
            ("89abcdef0123456789abcdef0123456789abcdef", False),
            ("", False),
            (captured_sha[:-1], False),
            ("$(exit 0)", False),
        ):
            with self.subTest(expected_sha=expected_sha):
                result = subprocess.run(
                    ["bash", "-c", github + gate],
                    env=os.environ
                    | {"DEPLOY_SHA": captured_sha, "EXPECTED_SHA": expected_sha},
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if accepted:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("NUC deployment revision mismatch", result.stderr)


subprocess_run = subprocess.run

if __name__ == "__main__":
    unittest.main()
