import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MANAGE = REPO_ROOT / "hosts" / "meshify" / "omarchy" / "manage"


@unittest.skipIf(sys.platform == "darwin", "Omarchy is Linux-only")
class ManageCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.module = self.root / "module"
        self.home = self.root / "home"
        self.module.mkdir()
        self.home.mkdir()
        shutil.copy2(MANAGE, self.module / "manage")

    def write_json(self, relative_path: str, value: object) -> None:
        path = self.module / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, indent=2) + "\n")

    def write_minimal_module(self) -> None:
        source = self.module / "config" / "omarchy" / "shell.json"
        source.parent.mkdir(parents=True)
        source.write_text('{"bar": {}}\n')
        self.write_json(
            "manifest.json",
            {
                "schemaVersion": 1,
                "host": "meshify",
                "omarchy": {"version": "4.0.0-1"},
                "files": [
                    {
                        "source": "config/omarchy/shell.json",
                        "target": ".config/omarchy/shell.json",
                        "mode": "0600",
                        "sourceMode": "0644",
                    }
                ],
                "packages": [],
                "services": [],
                "privateState": [],
                "keyringSecrets": [],
                "manualRecovery": [],
                "inventory": {
                    "roots": [".config/omarchy"],
                    "omarchyDefaults": [],
                    "generated": [],
                    "manual": [],
                },
            },
        )
        self.write_json("plugins.lock.json", {"schemaVersion": 1, "plugins": []})

    def run_manage(
        self, *arguments: str, env: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [self.module / "manage", *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def git(self, cwd: Path, *arguments: str) -> str:
        result = subprocess.run(
            ["git", "-C", cwd, *arguments],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()

    def create_plugin_remote(
        self, plugin_id: str = "example.plugin", setup_script: str | None = None
    ) -> tuple[Path, str, str]:
        work = self.root / "plugin-work"
        remote = self.root / "plugin.git"
        work.mkdir()
        self.git(work, "init", "-b", "main")
        self.git(work, "config", "user.name", "Test")
        self.git(work, "config", "user.email", "test@example.invalid")
        (work / "manifest.json").write_text(
            json.dumps(
                {
                    "id": plugin_id,
                    "name": "Example",
                    "description": "Fixture",
                    "version": "1.0.0",
                    "schemaVersion": 1,
                    "kinds": ["service"],
                    "entryPoints": {"service": "Service.qml"},
                }
            )
            + "\n"
        )
        (work / "Service.qml").write_text("// version one\n")
        if setup_script is not None:
            (work / "setup").write_text(setup_script)
            (work / "setup").chmod(0o755)
        self.git(work, "add", ".")
        self.git(work, "commit", "-m", "version one")
        first = self.git(work, "rev-parse", "HEAD")
        (work / "Service.qml").write_text("// version two\n")
        self.git(work, "commit", "-am", "version two")
        second = self.git(work, "rev-parse", "HEAD")
        subprocess.run(
            ["git", "clone", "--bare", work, remote],
            check=True,
            capture_output=True,
            text=True,
        )
        return remote, first, second

    def test_help_exposes_the_supported_interface(self) -> None:
        result = self.run_manage("--help")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("restore", result.stdout)
        self.assertIn("check", result.stdout)
        self.assertIn("snapshot", result.stdout)
        self.assertIn("update", result.stdout)

    def test_check_accepts_matching_declared_state_in_a_temporary_home(self) -> None:
        self.write_minimal_module()
        target = self.home / ".config" / "omarchy" / "shell.json"
        target.parent.mkdir(parents=True)
        shutil.copy2(self.module / "config" / "omarchy" / "shell.json", target)
        target.chmod(0o600)

        result = self.run_manage(
            "check", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("check: ok", result.stdout)

    def test_check_detects_declared_file_content_and_mode_drift(self) -> None:
        self.write_minimal_module()
        target = self.home / ".config" / "omarchy" / "shell.json"
        target.parent.mkdir(parents=True)
        target.write_text('{"bar": {"drift": true}}\n')
        target.chmod(0o644)

        result = self.run_manage(
            "check", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("declared file drift", result.stderr)
        self.assertIn("mode drift", result.stderr)

    def test_restore_is_idempotent_for_declared_files(self) -> None:
        self.write_minimal_module()
        target = self.home / ".config" / "omarchy" / "shell.json"

        first = self.run_manage(
            "restore", "--home", str(self.home), "--no-system", "--no-secrets"
        )
        first_mtime = target.stat().st_mtime_ns
        second = self.run_manage(
            "restore", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(target.read_text(), '{"bar": {}}\n')
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        self.assertEqual(target.stat().st_mtime_ns, first_mtime)
        self.assertIn("restore: unchanged", second.stdout)

    def test_restore_pins_plugins_and_check_detects_revision_drift(self) -> None:
        self.write_minimal_module()
        remote, locked_revision, newer_revision = self.create_plugin_remote()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["inventory"]["generated"] = [".config/omarchy/plugins/*"]
        self.write_json("manifest.json", manifest)
        self.write_json(
            "plugins.lock.json",
            {
                "schemaVersion": 1,
                "plugins": [
                    {
                        "id": "example.plugin",
                        "url": remote.as_uri(),
                        "revision": locked_revision,
                        "enabled": True,
                        "setup": "none",
                    }
                ],
            },
        )

        restored = self.run_manage(
            "restore", "--home", str(self.home), "--no-system", "--no-secrets"
        )
        checkout = self.home / ".config" / "omarchy" / "plugins" / "example.plugin"

        self.assertEqual(restored.returncode, 0, restored.stdout + restored.stderr)
        self.assertEqual(self.git(checkout, "rev-parse", "HEAD"), locked_revision)

        self.git(checkout, "checkout", "--detach", newer_revision)
        checked = self.run_manage(
            "check", "--home", str(self.home), "--no-system", "--no-secrets"
        )
        self.assertNotEqual(checked.returncode, 0)
        self.assertIn("plugin revision drift: example.plugin", checked.stderr)

    def test_snapshot_refuses_unknown_paths_and_copies_only_allowlisted_state(
        self,
    ) -> None:
        self.write_minimal_module()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["privateState"] = [
            {
                "id": "private-fixture",
                "target": ".config/omarchy/private.json",
                "mode": "0600",
                "onePasswordRef": "op://Private/fixture/value",
                "format": "json",
            }
        ]
        self.write_json("manifest.json", manifest)
        target = self.home / ".config" / "omarchy" / "shell.json"
        target.parent.mkdir(parents=True)
        target.write_text('{"bar": {"changed": true}}\n')
        target.chmod(0o600)
        private = target.parent / "private.json"
        private.write_text('{"token": "DO-NOT-COPY"}\n')
        private.chmod(0o600)
        unknown = target.parent / "unknown.txt"
        unknown.write_text("unclassified\n")

        refused = self.run_manage(
            "snapshot", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("unclassified active path", refused.stderr)
        self.assertEqual(
            (self.module / "config" / "omarchy" / "shell.json").read_text(),
            '{"bar": {}}\n',
        )
        self.assertNotIn("DO-NOT-COPY", refused.stdout + refused.stderr)

        unknown.unlink()
        captured = self.run_manage(
            "snapshot", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertEqual(captured.returncode, 0, captured.stdout + captured.stderr)
        self.assertEqual(
            (self.module / "config" / "omarchy" / "shell.json").read_text(),
            '{"bar": {"changed": true}}\n',
        )
        self.assertNotIn("DO-NOT-COPY", captured.stdout + captured.stderr)

    def test_restore_preserves_existing_private_state_when_onepassword_is_unavailable(
        self,
    ) -> None:
        self.write_minimal_module()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["privateState"] = [
            {
                "id": "private-fixture",
                "target": ".config/omarchy/private.json",
                "mode": "0600",
                "onePasswordRef": "op://Private/fixture/value",
                "format": "json",
            }
        ]
        self.write_json("manifest.json", manifest)
        private = self.home / ".config" / "omarchy" / "private.json"
        private.parent.mkdir(parents=True)
        private.write_text('{"token": "PRESERVE-CANARY"}\n')
        private.chmod(0o600)
        stale_temp = private.parent / ".meshify-private.stale"
        stale_temp.write_text("STALE-SECRET-CANARY")
        stale_temp.chmod(0o600)
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        op = fake_bin / "op"
        op.write_text("#!/usr/bin/env bash\nsleep 10\nexit 1\n")
        op.chmod(0o755)
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}:{env['PATH']}"
        env["MESHIFY_OMARCHY_OP_TIMEOUT"] = "0.1s"

        result = self.run_manage(
            "restore", "--home", str(self.home), "--no-system", env=env
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(private.read_text(), '{"token": "PRESERVE-CANARY"}\n')
        self.assertFalse(stale_temp.exists())
        self.assertIn("preserved existing private state", result.stderr)
        self.assertIn("check: ok (1 warning(s))", result.stdout)
        self.assertNotIn("PRESERVE-CANARY", result.stdout + result.stderr)

    def test_restore_streams_keyring_secrets_without_printing_or_argv_exposure(
        self,
    ) -> None:
        self.write_minimal_module()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["privateState"] = [
            {
                "id": "hass-config",
                "target": ".config/omarchy/hass/config.json",
                "mode": "0600",
                "onePasswordRef": "op://Private/meshify/hass-config",
                "format": "json",
            }
        ]
        manifest["keyringSecrets"] = [
            {
                "id": "hass-token",
                "onePasswordRef": "op://Private/meshify/hass-token",
                "adapter": "hass-token",
                "configTarget": ".config/omarchy/hass/config.json",
            }
        ]
        self.write_json("manifest.json", manifest)
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        op = fake_bin / "op"
        op.write_text(
            "#!/usr/bin/env bash\n"
            'case "${!#}" in\n'
            "  */hass-config) printf '%s' '{\"baseUrl\":\"https://ha.invalid\"}' ;;\n"
            "  */hass-token) printf '%s' 'KEYRING-SECRET-CANARY' ;;\n"
            "  *) exit 1 ;;\n"
            "esac\n"
        )
        op.chmod(0o755)
        secret_tool = fake_bin / "secret-tool"
        secret_tool.write_text(
            "#!/usr/bin/env bash\n"
            "[[ $1 == lookup ]] && exit 0\n"
            'printf \'%s\\n\' "$*" >"$SECRET_ARGV_CAPTURE"\n'
            'cat >"$SECRET_STDIN_CAPTURE"\n'
        )
        secret_tool.chmod(0o755)
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        env["PATH"] = f"{fake_bin}:{env['PATH']}"
        env["SECRET_ARGV_CAPTURE"] = str(self.root / "secret.argv")
        env["SECRET_STDIN_CAPTURE"] = str(self.root / "secret.stdin")

        result = self.run_manage("restore", "--no-system", env=env)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        combined = result.stdout + result.stderr
        self.assertNotIn("KEYRING-SECRET-CANARY", combined)
        self.assertNotIn(
            "KEYRING-SECRET-CANARY", Path(env["SECRET_ARGV_CAPTURE"]).read_text()
        )
        self.assertEqual(
            Path(env["SECRET_STDIN_CAPTURE"]).read_text(), "KEYRING-SECRET-CANARY"
        )

    def test_check_detects_system_dependency_service_and_version_failures(self) -> None:
        self.write_minimal_module()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["packages"] = [
            {"name": "missing-package", "manager": "repo", "command": "missing-cmd"}
        ]
        manifest["services"] = [{"name": "fixture.service", "setup": "omapods"}]
        self.write_json("manifest.json", manifest)
        target = self.home / ".config" / "omarchy" / "shell.json"
        target.parent.mkdir(parents=True)
        shutil.copy2(self.module / "config" / "omarchy" / "shell.json", target)
        target.chmod(0o600)
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        scripts = {
            "omarchy": "#!/usr/bin/env bash\n[[ $1 == version ]] && { echo 9.9.9; exit 0; }\nexit 1\n",
            "pacman": "#!/usr/bin/env bash\nexit 1\n",
            "systemctl": "#!/usr/bin/env bash\nexit 3\n",
            "hyprctl": "#!/usr/bin/env bash\nexit 0\n",
            "omarchy-shell": "#!/usr/bin/env bash\nexit 0\n",
        }
        for name, body in scripts.items():
            path = fake_bin / name
            path.write_text(body)
            path.chmod(0o755)
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        env["PATH"] = f"{fake_bin}:{env['PATH']}"

        result = self.run_manage("check", "--no-secrets", env=env)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incompatible Omarchy version", result.stderr)
        self.assertIn("missing package: missing-package", result.stderr)
        self.assertIn("inactive user service: fixture.service", result.stderr)

    def test_restore_installs_packages_and_runs_setup_once_per_locked_revision(
        self,
    ) -> None:
        self.write_minimal_module()
        remote, locked_revision, _ = self.create_plugin_remote(
            "io.github.thisisgm.omapods",
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            'echo setup >>"$ACTION_LOG"\n'
            'touch "$SERVICE_STATE"\n',
        )
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["packages"] = [
            {
                "name": "fixture-package",
                "manager": "repo",
                "command": "fixture-command",
            }
        ]
        manifest["services"] = [{"name": "fixture.service", "setup": "omapods"}]
        manifest["inventory"]["generated"] = [".config/omarchy/plugins/*"]
        self.write_json("manifest.json", manifest)
        self.write_json(
            "plugins.lock.json",
            {
                "schemaVersion": 1,
                "plugins": [
                    {
                        "id": "io.github.thisisgm.omapods",
                        "url": remote.as_uri(),
                        "revision": locked_revision,
                        "enabled": True,
                        "setup": "omapods",
                    }
                ],
            },
        )
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        action_log = self.root / "actions.log"
        package_state = self.root / "package.installed"
        service_state = self.root / "service.active"
        scripts = {
            "fixture-command": "#!/usr/bin/env bash\nexit 0\n",
            "pacman": (
                "#!/usr/bin/env bash\n[[ -e $PACKAGE_STATE ]] && exit 0\nexit 1\n"
            ),
            "omarchy": (
                "#!/usr/bin/env bash\n"
                "if [[ $1 == version ]]; then echo 4.0.0-1; exit 0; fi\n"
                'if [[ $1 == pkg ]]; then echo "$*" >>"$ACTION_LOG"; touch "$PACKAGE_STATE"; exit 0; fi\n'
                "if [[ $1 == plugin && $2 == validate ]]; then exit 0; fi\n"
                'if [[ $1 == plugin && $2 == list ]]; then printf \'%s\\n\' \'[{"id":"io.github.thisisgm.omapods","enabled":true}]\'; exit 0; fi\n'
                "exit 0\n"
            ),
            "omarchy-shell": "#!/usr/bin/env bash\nexit 0\n",
            "systemctl": (
                "#!/usr/bin/env bash\n[[ -e $SERVICE_STATE ]] && exit 0\nexit 3\n"
            ),
            "hyprctl": "#!/usr/bin/env bash\nexit 0\n",
        }
        for name, body in scripts.items():
            path = fake_bin / name
            path.write_text(body)
            path.chmod(0o755)
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(self.home),
                "PATH": f"{fake_bin}:{env['PATH']}",
                "ACTION_LOG": str(action_log),
                "PACKAGE_STATE": str(package_state),
                "SERVICE_STATE": str(service_state),
            }
        )

        first = self.run_manage("restore", "--no-secrets", env=env)
        second = self.run_manage("restore", "--no-secrets", env=env)

        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        actions = action_log.read_text().splitlines()
        self.assertEqual(actions.count("pkg add fixture-package"), 1)
        self.assertEqual(actions.count("setup"), 1)

    def test_update_intentionally_advances_the_lock_and_checkout(self) -> None:
        self.write_minimal_module()
        remote, locked_revision, newer_revision = self.create_plugin_remote()
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["inventory"]["generated"] = [".config/omarchy/plugins/*"]
        self.write_json("manifest.json", manifest)
        self.write_json(
            "plugins.lock.json",
            {
                "schemaVersion": 1,
                "plugins": [
                    {
                        "id": "example.plugin",
                        "url": remote.as_uri(),
                        "revision": locked_revision,
                        "enabled": True,
                        "setup": "none",
                    }
                ],
            },
        )
        restored = self.run_manage(
            "restore", "--home", str(self.home), "--no-system", "--no-secrets"
        )
        self.assertEqual(restored.returncode, 0, restored.stdout + restored.stderr)

        updated = self.run_manage(
            "update",
            "--home",
            str(self.home),
            "--no-system",
            "--no-secrets",
            "--yes",
        )
        lock = json.loads((self.module / "plugins.lock.json").read_text())
        checkout = self.home / ".config" / "omarchy" / "plugins" / "example.plugin"

        self.assertEqual(updated.returncode, 0, updated.stdout + updated.stderr)
        self.assertEqual(lock["plugins"][0]["revision"], newer_revision)
        self.assertEqual(self.git(checkout, "rev-parse", "HEAD"), newer_revision)
        self.assertIn("update: advanced example.plugin", updated.stdout)

    def test_check_rejects_duplicate_plugin_ids_and_unsafe_paths(self) -> None:
        self.write_minimal_module()
        lock_entry = {
            "id": "example.plugin",
            "url": "https://example.invalid/plugin.git",
            "revision": "a" * 40,
            "enabled": True,
            "setup": "none",
        }
        self.write_json(
            "plugins.lock.json",
            {"schemaVersion": 1, "plugins": [lock_entry, lock_entry]},
        )

        duplicate = self.run_manage(
            "check", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertNotEqual(duplicate.returncode, 0)
        self.assertIn("plugin lock schema validation failed", duplicate.stderr)

        self.write_json("plugins.lock.json", {"schemaVersion": 1, "plugins": []})
        manifest = json.loads((self.module / "manifest.json").read_text())
        manifest["files"][0]["target"] = "../outside"
        self.write_json("manifest.json", manifest)
        unsafe = self.run_manage(
            "check", "--home", str(self.home), "--no-system", "--no-secrets"
        )

        self.assertNotEqual(unsafe.returncode, 0)
        self.assertIn("unsafe declared file path", unsafe.stderr)


if __name__ == "__main__":
    unittest.main()
