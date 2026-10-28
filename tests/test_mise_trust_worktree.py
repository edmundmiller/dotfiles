import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "mise-trust-worktree"
HOOKS_SCRIPT = ROOT / "modules" / "shell" / "mise" / "claude-hooks.py"
CLEAN_CONFIG = '[env]\nFOO = "bar"\n'


class MiseTrustWorktreeTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for tool in ("bash", "git", "jq"):
            found = shutil.which(tool)
            self.assertIsNotNone(found, tool)
            (bin_dir / tool).symlink_to(found)
        self.mise_log = self.root / "mise.log"
        fake_mise = bin_dir / "mise"
        fake_mise.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$MISE_LOG"\n', encoding="utf-8"
        )
        fake_mise.chmod(0o755)
        self.env = {
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "HOME": str(self.root),
            "MISE_LOG": str(self.mise_log),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@example.com",
            "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@example.com",
        }

    def git(self, repo: Path, *args: str) -> None:
        subprocess.run(
            ["git", "-C", str(repo), *args],
            env=self.env,
            check=True,
            capture_output=True,
        )

    def make_repo(
        self,
        origin: str = "git@github.com:seqeralabs/x.git",
        name: str = "repo",
        files: dict[str, str] | None = None,
    ) -> Path:
        repo = self.root / name
        repo.mkdir()
        self.git(repo, "init", "-q", "-b", "main")
        for rel, text in (files or {"mise.toml": CLEAN_CONFIG}).items():
            (repo / rel).parent.mkdir(parents=True, exist_ok=True)
            (repo / rel).write_text(text, encoding="utf-8")
        (repo / ".gitignore").write_text("mise.local.toml\n", encoding="utf-8")
        self.git(repo, "add", "-A")
        self.git(repo, "commit", "-q", "-m", "init")
        self.git(repo, "remote", "add", "origin", origin)
        self.git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        self.git(
            repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"
        )
        return repo

    def run_script(
        self, *args: str, stdin: str = "", cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=cwd or self.root,
            env=self.env,
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
        )

    def hook(self, payload: dict) -> subprocess.CompletedProcess[str]:
        return self.run_script("--hook", stdin=json.dumps(payload))

    def trusted(self) -> list[str]:
        if not self.mise_log.exists():
            return []
        return self.mise_log.read_text(encoding="utf-8").splitlines()

    def test_allowlisted_unchanged_config_is_trusted(self) -> None:
        repo = self.make_repo(files={"mise.toml": CLEAN_CONFIG, ".tool-versions": "x 1\n"})

        result = self.run_script(str(repo))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            sorted(self.trusted()),
            sorted(
                [f"trust --quiet {repo}/mise.toml", f"trust --quiet {repo}/.tool-versions"]
            ),
        )
        self.assertIn(f"trusted {repo}/mise.toml", result.stdout)

    def test_defaults_to_current_directory_and_finds_top_level(self) -> None:
        repo = self.make_repo()
        (repo / "sub").mkdir()

        result = self.run_script(cwd=repo / "sub")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_https_origin_and_nested_config_paths_are_recognized(self) -> None:
        repo = self.make_repo(
            origin="https://github.com/Nextflow-IO/nextflow.git",
            files={".config/mise/conf.toml": CLEAN_CONFIG},
        )

        self.run_script(str(repo))

        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/.config/mise/conf.toml"])

    def test_modified_config_is_not_trusted(self) -> None:
        repo = self.make_repo()
        (repo / "mise.toml").write_text(CLEAN_CONFIG + 'EVIL = "1"\n', encoding="utf-8")

        result = self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])
        self.assertIn(f"mise trust {repo}/mise.toml", result.stdout)
        self.assertIn("origin/main", result.stdout)

    def test_committed_change_not_on_default_branch_is_not_trusted(self) -> None:
        repo = self.make_repo()
        (repo / "mise.toml").write_text(CLEAN_CONFIG + 'EVIL = "1"\n', encoding="utf-8")
        self.git(repo, "commit", "-qam", "branch change")

        self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])

    def test_untracked_config_blocks_trust_of_the_checkout(self) -> None:
        repo = self.make_repo()
        (repo / "mise.local.toml").write_text(CLEAN_CONFIG, encoding="utf-8")

        result = self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])
        self.assertIn(f"{repo}/mise.local.toml", result.stdout)

    def test_checkout_nested_in_another_checkout_is_not_trusted(self) -> None:
        outer = self.make_repo()
        (outer / ".claude" / "worktrees").mkdir(parents=True)
        nested = self.make_repo(name=f"{outer.name}/.claude/worktrees/nested")

        result = self.run_script(str(nested))

        self.assertEqual(self.trusted(), [])
        self.assertIn(f"mise: {nested} is nested in {outer}", result.stdout)
        self.assertIn(f"mise trust {nested}/mise.toml", result.stdout)

    def test_non_allowlisted_owner_is_not_trusted(self) -> None:
        repo = self.make_repo(origin="git@github.com:someone-else/x.git")

        result = self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])
        self.assertIn("someone-else/x", result.stdout)
        self.assertIn("not allowlisted", result.stdout)

    def test_missing_default_branch_ref_is_not_trusted(self) -> None:
        repo = self.make_repo()
        self.git(repo, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        self.git(repo, "update-ref", "-d", "refs/remotes/origin/main")

        result = self.run_script(str(repo))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.trusted(), [])
        self.assertIn("origin/main", result.stdout)

    def test_non_git_directory_is_a_silent_no_op(self) -> None:
        plain = self.root / "plain"
        plain.mkdir()
        (plain / "mise.toml").write_text(CLEAN_CONFIG, encoding="utf-8")

        result = self.run_script(str(plain))

        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.trusted(), [])

    def test_session_start_reports_as_plain_context(self) -> None:
        repo = self.make_repo()

        result = self.hook({"hook_event_name": "SessionStart", "cwd": str(repo)})

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"trusted {repo}/mise.toml", result.stdout)
        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_session_start_without_config_prints_nothing(self) -> None:
        repo = self.make_repo(files={"README": "x\n"})

        result = self.hook({"hook_event_name": "SessionStart", "cwd": str(repo)})

        self.assertEqual((result.returncode, result.stdout), (0, ""))

    def test_cwd_changed_trusts_silently(self) -> None:
        repo = self.make_repo()

        result = self.hook(
            {"hook_event_name": "CwdChanged", "old_cwd": "/", "new_cwd": str(repo)}
        )

        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_untrusted_failure_trusts_and_tells_the_model_to_retry(self) -> None:
        repo = self.make_repo(name="path with space")

        result = self.hook(
            {
                "hook_event_name": "PostToolUseFailure",
                "tool_name": "Bash",
                "error": f"Exit code 1\nmise ERROR Config files in {repo}/mise.toml are not trusted.",
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)["hookSpecificOutput"]
        self.assertEqual(output["hookEventName"], "PostToolUseFailure")
        self.assertIn(f"trusted {repo}/mise.toml", output["additionalContext"])
        self.assertIn("Retry the failed command", output["additionalContext"])
        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_untrusted_failure_with_home_relative_path(self) -> None:
        repo = self.make_repo()

        result = self.hook(
            {
                "hook_event_name": "PostToolUseFailure",
                "error": "mise ERROR Config files in ~/repo/mise.toml are not trusted.",
            }
        )

        self.assertIn(f"trusted {repo}/mise.toml", result.stdout)
        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_untrusted_failure_in_blocked_checkout_asks_for_review(self) -> None:
        repo = self.make_repo(origin="git@github.com:someone-else/x.git")

        result = self.hook(
            {
                "hook_event_name": "PostToolUseFailure",
                "error": f"mise ERROR Config files in {repo}/mise.toml are not trusted.",
            }
        )

        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("not allowlisted", context)
        self.assertIn("ask the user", context)
        self.assertEqual(self.trusted(), [])

    def test_unrelated_failures_and_events_are_silent(self) -> None:
        repo = self.make_repo()
        for payload in (
            {"hook_event_name": "PostToolUseFailure", "error": "Exit code 1\nboom"},
            {"hook_event_name": "PostToolUseFailure"},
            {"hook_event_name": "Stop", "cwd": str(repo)},
            {"hook_event_name": "apply", "cwd": str(repo)},
        ):
            with self.subTest(payload=payload):
                result = self.hook(payload)
                self.assertEqual((result.returncode, result.stdout), (0, ""))
        result = self.run_script("--hook", stdin="not json")
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.trusted(), [])


    def test_default_branch_falls_back_to_origin_master(self) -> None:
        repo = self.make_repo()
        self.git(repo, "update-ref", "refs/remotes/origin/master", "HEAD")
        self.git(repo, "update-ref", "-d", "refs/remotes/origin/main")
        self.git(repo, "update-ref", "-d", "refs/remotes/origin/HEAD")

        self.run_script(str(repo))

        self.assertEqual(self.trusted(), [f"trust --quiet {repo}/mise.toml"])

    def test_skip_worktree_config_is_not_trusted(self) -> None:
        repo = self.make_repo()
        (repo / "mise.toml").write_text('[env]\nFOO = "changed"\n', encoding="utf-8")
        self.git(repo, "update-index", "--skip-worktree", "mise.toml")

        result = self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])
        self.assertIn("skip-worktree", result.stdout)

    def test_symlinked_config_is_not_trusted(self) -> None:
        repo = self.make_repo(files={"real.toml": CLEAN_CONFIG})
        os.symlink("real.toml", repo / "mise.toml")
        self.git(repo, "add", "mise.toml")
        self.git(repo, "commit", "-q", "-m", "link")
        self.git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        (repo / "real.toml").write_text('[env]\nFOO = "changed"\n', encoding="utf-8")

        result = self.run_script(str(repo))

        self.assertEqual(self.trusted(), [])
        self.assertIn("is a symlink", result.stdout)


class ClaudeHookRegistrationTests(unittest.TestCase):
    def test_registration_replaces_stale_entries_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            entire = {"type": "command", "command": "entire hooks claude-code session-start"}
            settings.write_text(
                json.dumps(
                    {
                        "permissions": {"allow": ["Read(**)"]},
                        "hooks": {
                            "SessionStart": [
                                {
                                    "matcher": "",
                                    "hooks": [
                                        entire,
                                        {
                                            "type": "command",
                                            "command": "/nix/store/old/bin/mise-trust-worktree --hook",
                                        },
                                    ],
                                }
                            ],
                            "CwdChanged": [
                                {
                                    "hooks": [
                                        {
                                            "type": "command",
                                            "command": "/nix/store/old/bin/mise-trust-worktree --hook",
                                        }
                                    ]
                                }
                            ],
                        },
                    }
                ),
                encoding="utf-8",
            )
            command = "/nix/store/new/bin/mise-trust-worktree --hook"
            ours = [{"type": "command", "command": command}]

            for _ in range(2):
                subprocess.run(
                    [sys.executable, str(HOOKS_SCRIPT), str(settings), command], check=True
                )
            first = settings.read_text(encoding="utf-8")
            subprocess.run(
                [sys.executable, str(HOOKS_SCRIPT), str(settings), command], check=True
            )

            self.assertEqual(settings.read_text(encoding="utf-8"), first)
            data = json.loads(first)
            self.assertEqual(data["permissions"], {"allow": ["Read(**)"]})
            self.assertNotIn("/nix/store/old/", first)
            self.assertEqual(
                data["hooks"],
                {
                    "SessionStart": [
                        {"matcher": "", "hooks": [entire]},
                        {"matcher": "", "hooks": ours},
                    ],
                    "CwdChanged": [{"hooks": ours}],
                    "PostToolUseFailure": [{"matcher": "Bash", "hooks": ours}],
                },
            )

    def test_empty_command_removes_only_our_registrations(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            entire = {"type": "command", "command": "entire hooks claude-code session-start"}
            ours_hook = {"type": "command", "command": "/nix/store/old/bin/mise-trust-worktree --hook"}
            settings.write_text(
                json.dumps(
                    {
                        "hooks": {
                            "SessionStart": [{"matcher": "", "hooks": [entire, ours_hook]}],
                            "CwdChanged": [{"hooks": [ours_hook]}],
                            "PostToolUseFailure": [{"matcher": "Bash", "hooks": [ours_hook]}],
                        }
                    }
                ),
                encoding="utf-8",
            )

            subprocess.run([sys.executable, str(HOOKS_SCRIPT), str(settings)], check=True)

            self.assertEqual(
                json.loads(settings.read_text(encoding="utf-8"))["hooks"],
                {"SessionStart": [{"matcher": "", "hooks": [entire]}]},
            )


if __name__ == "__main__":
    unittest.main()
