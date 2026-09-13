"""Validation routing and isolation, with real disposable Git repositories."""

import contextlib
import io
import json
import os
import shutil
import subprocess
import tempfile
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
            self.write("modules/shell/herdr/default.nix", "affected")
            self.assertEqual(
                self.selection("--ci", "--platform", "herdr-vm")["platform"], "herdr-vm"
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
        self.assertFalse((v.ROOT / ".omp/hooks/post/completion-gate.ts").exists())
        self.assertFalse((v.ROOT / "scripts/codex-validate-stop").exists())

    def test_full_includes_clean_sources_and_does_not_imply_platform_checks(self):
        self.package("omp-example")
        self.commit()
        selected = self.selection("--full")
        self.assertIn("tracked.md", selected["files"])
        self.assertIn("validation-tests", selected["checks"])
        self.assertIn("omp-example", selected["packages"])
        self.assertIsNone(selected["platform"])
        self.assertNotIn("trmnl-agent-message-render", selected["checks"])
        self.assertFalse(
            any("dji" in name or "vm-test" in name for name in selected["checks"])
        )

    def test_shared_lock_and_tests_only_changes_check_all_packages(self):
        self.package("pi-a")
        self.package("omp-b")
        for file in [
            "packages/pi-packages/bun.lock",
            "packages/pi-packages/tests/example.test.ts",
            "packages/pi-packages/package.json",
        ]:
            with self.subTest(file=file):
                packages, integration = v.package_plan(self.root, [file])
                self.assertEqual(packages, ["omp-b", "pi-a"])
                self.assertTrue(integration)

    def test_transitive_dependents_not_unrelated_packages(self):
        self.package("pi-a")
        self.package("omp-b", {"@test/pi-a": "workspace:*"})
        self.package("pi-c", {"@test/omp-b": "workspace:*"})
        self.package("pi-unrelated")
        packages, integration = v.package_plan(
            self.root, ["packages/pi-packages/pi-a/index.ts"]
        )
        self.assertEqual(packages, ["omp-b", "pi-a", "pi-c"])
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
            ".#checks.aarch64-darwin.dji-mic-mini-receiver-mute-regressions",
            [command[-1] for command in commands if "build" in command],
        )

    def test_snapshot_is_unsigned_preserves_source_index_and_internal_links(self):
        self.write("ignored/node_modules/state", "keep")
        self.write(".gitignore", "ignored/\n")
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

    @unittest.skipUnless(shutil.which("nu"), "Nushell required for hey parity")
    def test_hey_and_direct_ci_entry_select_identical_work(self):
        (self.root / "scripts").mkdir()
        shutil.copy2(
            v.ROOT / "scripts/validation.py", self.root / "scripts/validation.py"
        )
        self.write("owned space.md", "edit")
        env = os.environ | {"FLAKE_DIR": str(self.root)}
        result = subprocess.run(
            [
                "nu",
                "--no-config-file",
                "--commands",
                f"source '{v.ROOT}/bin/hey.d/flake.nu'; main check --plan 'owned space.md'",
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
        self.assertIn("needs: darwin\n    if: always()", workflow)
        self.assertIn("if: needs.darwin.result != 'success'", workflow)
        darwin = workflow.split("  darwin:")[1].split("  vm-services:")[0]
        self.assertIn("runs-on: macos-15", darwin)
        self.assertNotIn("if:", darwin)


subprocess_run = subprocess.run

if __name__ == "__main__":
    unittest.main()
