"""Exercise native NUC routing and snapshots without host or privileged effects."""

import csv
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

SOURCE = Path(__file__).resolve().parent
REPOSITORY = SOURCE.parent.parent
PRUNER = Path(os.environ.get("HEY_TEST_NUC_PRUNER", REPOSITORY / "bin/prune-nuc-deploy-snapshots"))
REVISION_WRITER = Path(os.environ.get("HEY_TEST_NUC_REVISION_WRITER", REPOSITORY / "bin/write-nuc-deploy-revision"))


class NativeNucTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey nuc native build ")
        cls.addClassCleanup(cls.build.cleanup)
        cls.build_root = Path(cls.build.name).resolve()
        cls.remote = cls.build_root / "remote snapshots"
        cls.tools = cls.build_root / "tools"
        cls.tools.mkdir()
        cls.meminfo = cls.build_root / "meminfo"
        cls.meminfo.write_text("MemAvailable: 50000000 kB\n")
        native = cls.build_root / "native source"
        native.mkdir()
        for path in SOURCE.iterdir():
            if path.suffix in (".bend", ".c", ".h") or path.name == "build":
                shutil.copy2(path, native / path.name)
        policy = native / "nuc-policy.bend"
        original = 'def snapshot_storage_root() -> String:\n  "/tmp"'
        text = policy.read_text()
        if text.count(original) != 1:
            raise RuntimeError("snapshot storage boundary changed")
        policy.write_text(text.replace(original, 'def snapshot_storage_root() -> String:\n  ' + json.dumps(str(cls.remote))))
        plan = native / "nuc-plan.bend"
        text = plan.read_text().replace('  "/run/wrappers/bin/sudo"', "  " + json.dumps(str(cls.tools / "sudo")))
        text = text.replace('  "/proc/meminfo"', "  " + json.dumps(str(cls.meminfo)))
        plan.write_text(text)
        posix = native / "posix.c"
        text = posix.read_text()
        for function, environment, fallback in (("host_name", "HEY_NUC_TEST_HOST", "fixture"),
                                                 ("platform_name", "HEY_NUC_TEST_PLATFORM", "Darwin")):
            pattern = rf"static Term hey_{function}\(Env e, Term \*f, IoWork \*w\) \{{.*?\n\}}"
            replacement = (f"static Term hey_{function}(Env e, Term *f, IoWork *w) {{\n"
                           f'  const char *value = getenv("{environment}");\n'
                           f'  if (!value) value = "{fallback}";\n'
                           "  return io_str(e, value, strlen(value));\n}")
            text, count = re.subn(pattern, lambda match: replacement, text, flags=re.DOTALL)
            if count != 1:
                raise RuntimeError(f"native {function} boundary changed")
        posix.write_text(text)
        privilege = native / "privilege.bend"
        text = privilege.read_text()
        original = 'privileged_path(["/run/wrappers/bin", "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin"], current)'
        if text.count(original) != 1:
            raise RuntimeError("privileged search-path boundary changed")
        privilege.write_text(text.replace(original, "IO.pure(String, current)"))
        cls.binaries = {}
        for family in ("nuc", "snapshot"):
            binary = cls.build_root / family
            subprocess.run(["bash", str(native / "build"), str(binary), "/unused/mise", f"{family}-main.bend"], check=True)
            cls.binaries[family] = binary

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey nuc source fixture ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "source checkout ' with spaces"
        self.root.mkdir()
        if self.remote.exists():
            shutil.rmtree(self.remote)
        self.remote.mkdir()
        self.meminfo.write_text("MemAvailable: 50000000 kB\n")
        self.git = shutil.which("git")
        self.bash = shutil.which("bash")
        self.log = self.base / "commands.jsonl"
        self.env = os.environ | {
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "HOME": str(self.base),
            "MISE_PROJECT_ROOT": str(self.root), "FLAKE_DIR": "/wrong-checkout", "FLAKE_HOST": "nuc",
            "USER": "tester", "HOSTNAME": "source-host", "HEY_NUC_LOG": str(self.log),
            "HEY_NUC_SOURCE": str(self.root), "HEY_NUC_REMOTE": str(self.remote),
            "HEY_REAL_GIT": self.git, "HEY_REAL_BASH": self.bash,
            "HEY_NUC_SNAPSHOT_BINARY": str(self.binaries["snapshot"]), "HEY_PRIVILEGE_EXIT": "17",
        }
        self.env.pop("GIT_INDEX_FILE", None)
        (self.root / "bin").mkdir()
        for source, name in ((REVISION_WRITER, "write-nuc-deploy-revision"), (PRUNER, "prune-nuc-deploy-snapshots")):
            destination = self.root / "bin" / name
            shutil.copy2(source, destination)
            destination.chmod(destination.stat().st_mode | 0o200)
        shutil.copytree(SOURCE / "workers", self.root / "packages/hey/workers")
        (self.root / "flake.nix").write_text("committed flake bytes\n")
        self.agents_revision = "2" * 40
        self.lock = {"root": "root", "nodes": {"root": {"inputs": {"agents-workspace": "agents-workspace"}},
                                                "agents-workspace": {"locked": {"rev": self.agents_revision}}}}
        (self.root / "flake.lock").write_text(json.dumps(self.lock))
        (self.root / ".gitignore").write_text("ignored.txt\n.pi/\nconfig/jj/\n")
        for name, value in (("config/jj/config.toml", "tracked ignored config"), (".pi/tracked.txt", "tracked Pi source")):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        self.git_run("init", "--quiet")
        self.git_run("add", "-f", ".")
        self.commit()
        self.head = self.git_run("rev-parse", "HEAD").strip()
        self.git_run("update-ref", "refs/remotes/origin/main", self.head)
        (self.root / "ignored.txt").write_text("ignored runtime state")
        (self.root / ".pi/runtime").mkdir()
        (self.root / ".pi/runtime/session.json").write_text("ignored Pi runtime")
        self.env["HEY_EXPECTED_REVISION"] = f"dotfiles={self.head};agents-workspace={self.agents_revision}"
        self.make_tools()
        self.env["PATH"] = str(self.tools) + os.pathsep + os.environ["PATH"]

    def git_run(self, *args):
        return subprocess.run([self.git, "-C", str(self.root), *args], env=self.env,
                              capture_output=True, text=True, check=True).stdout

    def commit(self):
        self.git_run("add", "-A", ".")
        self.git_run("-c", "user.name=Fixture", "-c", "user.email=fixture@localhost",
                     "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "fixture")

    def tool(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def make_tools(self):
        common = (
            "import json, os, pathlib, shlex, subprocess, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\nargs = sys.argv[1:]\n"
            "with open(os.environ['HEY_NUC_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, args, os.getcwd()]) + '\\n')\n"
        )
        self.tool("git", common +
                  "assert not set(args).intersection({'push', 'pull', 'fetch', 'clone', 'rebase'})\n"
                  "if 'archive' in args and os.environ.get('HEY_ARCHIVE_FAIL') == '1': raise SystemExit(44)\n"
                  "os.execv(os.environ['HEY_REAL_GIT'], [os.environ['HEY_REAL_GIT'], *args])\n")
        self.tool("ssh", common +
                  "assert len(args) == 2 and args[0] == 'nuc'\n"
                  "command = args[1]\n"
                  "assert '/tmp/dotfiles-worktree-' not in command, 'fixture must never reach real snapshot storage'\n"
                  "argv = shlex.split(command)\n"
                  "if argv[0] == 'tar' and os.environ.get('HEY_MUTATE_SOURCE') == '1':\n"
                  "    result = subprocess.run([os.environ['HEY_REAL_BASH'], '-c', command])\n"
                  "    (pathlib.Path(os.environ['HEY_NUC_SOURCE']) / 'flake.nix').write_text('mutated during transfer')\n"
                  "    raise SystemExit(result.returncode)\n"
                  "os.execv(os.environ['HEY_REAL_BASH'], [os.environ['HEY_REAL_BASH'], '-c', command])\n")
        self.tool("tailscale", common +
                  "assert args[:2] == ['ssh', 'emiller@nuc.cinnamon-rooster.ts.net'] and len(args) == 3\n"
                  "os.execv(os.environ['HEY_REAL_BASH'], [os.environ['HEY_REAL_BASH'], '-c', args[2]])\n")
        self.tool("mise", common +
                  "assert args[:3] == ['run', 'nuc:worktree', '--']\n"
                  "binary = os.environ['HEY_NUC_SNAPSHOT_BINARY']\n"
                  "os.execv(binary, [binary, 'nuc:worktree', *args[3:]])\n")
        self.tool("sudo", common + "raise SystemExit(int(os.environ.get('HEY_PRIVILEGE_EXIT', '17')))\n")
        self.tool("hostname", common + "assert args == ['-s']\nprint(os.environ.get('HEY_REMOTE_HOST', 'nuc'))\n")
        self.tool("uname", common +
                  "assert args in (['-s'], ['-a'])\n"
                  "print(os.environ.get('HEY_REMOTE_PLATFORM', 'Linux') if args == ['-s'] else 'Linux nuc fixture')\n")
        self.tool("nixos-version", common +
                  "assert args == ['--configuration-revision']\nprint(os.environ['HEY_EXPECTED_REVISION'])\n")
        self.tool("systemctl", common +
                  "if args[:2] == ['--user', 'show']:\n"
                  "    print(os.environ.get('HEY_UNIT_LOAD', 'not-found'))\n"
                  "elif args[:2] == ['--user', 'is-active']:\n"
                  "    statuses = json.loads(os.environ.get('HEY_UNIT_ACTIVE_MAP', '{}'))\n"
                  "    raise SystemExit(int(statuses.get(args[-1], os.environ.get('HEY_UNIT_ACTIVE_EXIT', '3'))))\n"
                  "elif 'nixos-upgrade.timer' in args:\n"
                  "    key = 'HEY_TIMER_ACTIVE' if args[0] == 'is-active' else 'HEY_TIMER_ENABLED'\n"
                  "    raise SystemExit(int(os.environ.get(key, '3')))\n"
                  "else: print('fixture service observation')\n")
        self.tool("flock", common + "assert args == ['9']\n")
        self.tool("python3", common +
                  "assert args in (['scripts/validation.py', '--full'], ['scripts/validation.py', '--platform', 'nixos'])\n"
                  "key = 'HEY_FULL_EXIT' if args[-1] == '--full' else 'HEY_NIXOS_EXIT'\n"
                  "print('fixture validation gate output')\n"
                  "raise SystemExit(int(os.environ.get(key, '0')))\n")
        self.tool("nix", common +
                  "assert args == ['flake', 'check', '--keep-going', '-L']\n"
                  "print('fixture flake gate output')\n"
                  "raise SystemExit(int(os.environ.get('HEY_FLAKE_EXIT', '0')))\n")
        self.tool("systemd-run", common +
                  "assert '--user' in args and '--wait' in args and '--collect' in args\n"
                  "assert '--property=MemoryHigh=10G' in args and '--property=MemoryMax=12G' in args\n"
                  "assert '--property=OOMPolicy=continue' in args\n"
                  "if os.environ.get('HEY_SYSTEMD_MODE', 'run') != 'run': raise SystemExit(42)\n"
                  "post = next(arg.split('=', 2)[2] for arg in args if arg.startswith('--property=ExecStopPost='))\n"
                  "post_argv = shlex.split(post)\n"
                  "assert len(post_argv) == 3 and post_argv[:2] == ['/bin/sh', '-c']\n"
                  "start = args.index('bash')\n"
                  "main = subprocess.run(args[start:])\n"
                  "environment = os.environ | {'SERVICE_RESULT': 'success' if main.returncode == 0 else 'exit-code',\n"
                  "                            'EXIT_CODE': 'exited', 'EXIT_STATUS': str(main.returncode)}\n"
                  "finalizer = subprocess.run(post_argv, env=environment)\n"
                  "raise SystemExit(main.returncode or finalizer.returncode)\n")

    def run_task(self, family, *args):
        return subprocess.run([self.binaries[family], *args], cwd=self.base, env=self.env,
                              capture_output=True, text=True, timeout=20)

    def snapshot(self, mode="build", configuration="nuc"):
        return self.run_task("snapshot", "nuc:worktree", mode, configuration)

    def commands(self, name=None):
        rows = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return [row for row in rows if name is None or row[0] == name]

    def snapshot_path(self, result, phase):
        match = re.search(r"^NUC_WORKTREE_REMOTE_DIR=(.+)$", result.stdout, re.MULTILINE)
        self.assertIsNotNone(match, result.stdout + result.stderr)
        path = Path(match[1])
        self.assertEqual(path.parent, self.remote)
        self.assertTrue(path.name.startswith(f"dotfiles-worktree-tester-{self.head}-{phase}-"))
        self.assertEqual(uuid.UUID(path.name[-36:]).version, 4)
        return path

    def test_clean_snapshot_materializes_committed_blobs_and_retains_tracked_ignored_source(self):
        self.git_run("update-index", "--assume-unchanged", "flake.nix")
        (self.root / "flake.nix").write_text("hidden worktree mutation")
        result = self.snapshot()
        self.assertEqual(result.returncode, 17, result.stderr)
        path = self.snapshot_path(result, "clean")
        self.assertEqual((path / "flake.nix").read_text(), "committed flake bytes\n")
        self.assertEqual((path / "config/jj/config.toml").read_text(), "tracked ignored config")
        self.assertEqual((path / ".pi/tracked.txt").read_text(), "tracked Pi source")
        for name in (".git", "ignored.txt", ".pi/runtime/session.json", ".nuc-deploy-active"):
            self.assertFalse((path / name).exists(), name)
        self.assertEqual((path / ".nuc-deploy-source-revision").read_text(), self.head)
        self.assertEqual(self.commands("sudo")[-1][1],
                         ["nix-private-github", "nixos-rebuild", "build", "--flake", str(path) + "#nuc",
                          "--show-trace", "--accept-flake-config", "--max-jobs", "1"])
        self.assertEqual((self.root / "flake.nix").read_text(), "hidden worktree mutation")

    def test_dirty_snapshot_captures_worktree_bytes_without_staging_the_callers_index(self):
        self.git_run("update-index", "--assume-unchanged", "flake.nix")
        (self.root / "flake.nix").write_text("hidden dirty flake")
        (self.root / "untracked.txt").write_text("uncommitted source")
        before = self.git_run("ls-files", "--stage")
        result = self.snapshot()
        self.assertEqual(result.returncode, 17, result.stderr)
        path = self.snapshot_path(result, "dirty")
        self.assertEqual((path / "flake.nix").read_text(), "hidden dirty flake")
        self.assertEqual((path / "untracked.txt").read_text(), "uncommitted source")
        self.assertEqual((path / ".nuc-deploy-source-revision").read_text(), self.head + "-dirty")
        self.assertEqual(self.git_run("ls-files", "--stage"), before)
        self.assertFalse((path / ".nuc-deploy-active").exists())
        self.assertFalse((path / ".pi/runtime/session.json").exists())

    def test_dirty_activation_and_unknown_modes_or_configurations_cannot_contact_a_host(self):
        (self.root / "untracked.txt").write_text("user work")
        for mode, configuration in (("dry-activate", "nuc"), ("test", "nuc"), ("switch", "nuc"),
                                    ("bad-mode", "nuc"), ("build", "bad-config")):
            with self.subTest(mode=mode, configuration=configuration):
                self.log.unlink(missing_ok=True)
                result = self.snapshot(mode, configuration)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.commands("ssh"), [])
                self.assertEqual(self.commands("sudo"), [])
                self.assertEqual(list(self.remote.iterdir()), [])

    def test_target_identity_is_checked_before_snapshot_mutations(self):
        for key, value in (("HEY_REMOTE_HOST", "another-machine"), ("HEY_REMOTE_PLATFORM", "Darwin")):
            with self.subTest(key=key):
                self.env[key] = value
                result = self.snapshot()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(list(self.remote.iterdir()), [])
                self.assertEqual(self.commands("sudo"), [])
                self.env.pop(key)

    def test_dirty_virtual_machine_build_keeps_configuration_and_never_adds_activation_flags(self):
        (self.root / "untracked.txt").write_text("vm source")
        result = self.snapshot("vm", "nuc-buzz-scintillate-finn")
        self.assertEqual(result.returncode, 17, result.stderr)
        path = self.snapshot_path(result, "dirty")
        args = self.commands("sudo")[-1][1]
        self.assertEqual(args[:3], ["nix-private-github", "nix", "build"])
        self.assertIn(str(path) + "#nixosConfigurations.nuc-buzz-scintillate-finn.config.system.build.vm", args)
        self.assertFalse(any(arg.startswith("--nuc-deploy-source-") for arg in args))

    def test_clean_activation_carries_literal_provenance_and_the_explicit_stale_override(self):
        self.env["NUC_DEPLOY_ALLOW_STALE"] = "1"
        result = self.snapshot("dry-activate")
        self.assertEqual(result.returncode, 17, result.stderr)
        path = self.snapshot_path(result, "clean")
        args = self.commands("sudo")[-1][1]
        self.assertEqual(args[:5], ["nix-private-github", "--nuc-deploy-source-head=" + self.head,
                                  "--nuc-deploy-source-base=" + self.head,
                                  "--nuc-deploy-source-owner=tester@source-host", "--nuc-deploy-allow-stale"])
        self.assertIn("dry-activate", args)
        self.assertFalse((path / ".nuc-deploy-active").exists())

    def test_source_mutation_during_transfer_stops_before_build_and_releases_the_lease(self):
        (self.root / "untracked.txt").write_text("stable initially")
        self.env["HEY_MUTATE_SOURCE"] = "1"
        result = self.snapshot()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source changed", result.stderr)
        path = self.snapshot_path(result, "dirty")
        self.assertFalse((path / ".nuc-deploy-active").exists())
        self.assertEqual(self.commands("sudo"), [])
        self.assertEqual((self.root / "flake.nix").read_text(), "mutated during transfer")

    def test_archive_failure_before_any_copy_still_releases_the_destination_lease(self):
        self.env["HEY_ARCHIVE_FAIL"] = "1"
        result = self.snapshot()
        self.assertEqual(result.returncode, 44, result.stderr)
        path = self.snapshot_path(result, "clean")
        self.assertFalse((path / "bin").exists())
        self.assertFalse((path / ".nuc-deploy-active").exists())
        self.assertEqual(self.commands("sudo"), [])

    def test_missing_revision_writer_cannot_reach_a_build(self):
        (self.root / "bin/write-nuc-deploy-revision").unlink()
        self.commit()
        self.head = self.git_run("rev-parse", "HEAD").strip()
        result = self.snapshot()
        self.assertNotEqual(result.returncode, 0)
        path = self.snapshot_path(result, "clean")
        self.assertFalse((path / ".nuc-deploy-active").exists())
        self.assertEqual(self.commands("sudo"), [])

    def test_parent_modes_keep_mise_orchestration_and_auto_build_cannot_activate_locally(self):
        self.env.update(HEY_NUC_TEST_HOST="nuc", HEY_NUC_TEST_PLATFORM="Linux")
        result = self.run_task("nuc", "nuc", "auto", "build")
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual(self.commands("mise")[-1][1], ["run", "nuc:worktree", "--", "build"])
        args = self.commands("sudo")[-1][1]
        self.assertIn("build", args)
        self.assertNotIn("switch", args)

    def test_local_activation_requires_actual_host_identity_not_a_flake_host_override(self):
        result = self.run_task("nuc", "nuc", "local")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("sudo"), [])
        self.assertEqual(self.commands("ssh"), [])

    def test_revision_deploy_uses_the_approved_lock_and_verifies_both_revisions(self):
        self.env["HEY_PRIVILEGE_EXIT"] = "0"
        result = self.run_task("nuc", "nuc", "revision", self.head)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.commands("sudo")[-1][1]
        self.assertEqual(args[:3], ["-n", "nix-private-github", "--nuc-deploy-expected-main=" + self.head])
        self.assertIn("github:edmundmiller/dotfiles/" + self.head + "#nuc", args)
        self.assertIn("configurationRevision=" + self.env["HEY_EXPECTED_REVISION"], result.stdout)
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_revision_verification_rejects_a_different_running_pin_or_enabled_upgrade_timer(self):
        self.env["HEY_PRIVILEGE_EXIT"] = "0"
        for key, value in (("HEY_EXPECTED_REVISION", "different-running-pin"), ("HEY_TIMER_ACTIVE", "0"), ("HEY_TIMER_ENABLED", "0")):
            with self.subTest(key=key):
                original = self.env.get(key)
                self.env[key] = value
                result = self.run_task("nuc", "nuc", "revision", self.head)
                self.assertNotEqual(result.returncode, 0)
                if original is None:
                    self.env.pop(key)
                else:
                    self.env[key] = original

    def test_invalid_revision_and_missing_exact_agents_pin_never_open_a_tailnet_connection(self):
        for revision in ("bad", "A" * 40, "a" * 41):
            result = self.run_task("nuc", "nuc", "revision", revision)
            self.assertEqual(result.returncode, 2, result.stderr)
        self.lock["nodes"]["agents-workspace"]["locked"]["rev"] = " " + self.agents_revision
        (self.root / "flake.lock").write_text(json.dumps(self.lock))
        self.commit()
        revision = self.git_run("rev-parse", "HEAD").strip()
        result = self.run_task("nuc", "nuc", "revision", revision)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("tailscale"), [])
        self.assertEqual(self.commands("sudo"), [])

    def test_native_snapshot_lifecycle_retains_five_completed_snapshots(self):
        old = []
        for number in range(1, 7):
            path = self.remote / f"dotfiles-worktree-tester-{self.head}-clean-{uuid.UUID(int=number)}"
            path.mkdir()
            timestamp = int(time.time()) - 1000 + number
            os.utime(path, (timestamp, timestamp))
            old.append(path)
        result = self.snapshot()
        self.assertEqual(result.returncode, 17, result.stderr)
        current = self.snapshot_path(result, "clean")
        self.assertTrue(current.exists())
        self.assertEqual([path.exists() for path in old], [False, False, True, True, True, True])
        self.assertEqual(len(list(self.remote.glob("dotfiles-worktree-tester-*"))), 5)

    def report_path(self, result):
        match = re.search(r"^NUC_VALIDATION_REPORT_DIR=(.+)$", result.stdout, re.MULTILINE)
        self.assertIsNotNone(match, result.stdout + result.stderr)
        path = Path(match[1])
        self.assertEqual(path.parent, self.remote)
        return path

    @staticmethod
    def report_rows(report, name):
        with (report / name).open() as file:
            return list(csv.DictReader(file, delimiter="\t"))

    def test_validation_runs_all_selected_gates_and_finalizes_the_exact_dirty_snapshot(self):
        (self.root / "untracked.txt").write_text("validated dirty bytes")
        self.env.update(HEY_FULL_EXIT="3", HEY_FLAKE_EXIT="5")
        result = self.snapshot("validate")
        self.assertEqual(result.returncode, 1, result.stderr)
        path = self.snapshot_path(result, "dirty")
        report = self.report_path(result)
        rows = self.report_rows(report, "summary.tsv")
        self.assertEqual([(row["gate"], row["status"], row["log_status"]) for row in rows],
                         [("full", "3", "0"), ("nixos", "0", "0"), ("flake-check", "5", "0")])
        self.assertEqual([row[1] for row in self.commands("python3")],
                         [["scripts/validation.py", "--full"], ["scripts/validation.py", "--platform", "nixos"]])
        self.assertEqual(self.commands("nix")[-1][1], ["flake", "check", "--keep-going", "-L"])
        self.assertEqual(self.report_rows(report, "state.tsv")[-1]["outcome"], "gates")
        self.assertEqual((path / "untracked.txt").read_text(), "validated dirty bytes")
        self.assertFalse((path / ".nuc-deploy-active").exists())
        digest = subprocess.run([self.git, "-C", str(path), "rev-parse", "HEAD^{tree}"], env=self.env,
                                capture_output=True, text=True, check=True).stdout.strip()
        self.assertIn("content_digest=git-tree:" + digest, (report / "provenance.txt").read_text())
        self.assertEqual(self.commands("sudo"), [])

    def test_native_submission_rejection_and_uncertainty_have_different_lease_ownership(self):
        for mode, load, active, status, retained in (("rejected", "not-found", "3", 1, False),
                                                    ("uncertain", "loaded", "1", 42, True)):
            with self.subTest(mode=mode):
                self.env.update(HEY_SYSTEMD_MODE=mode, HEY_UNIT_LOAD=load, HEY_UNIT_ACTIVE_EXIT=active)
                result = self.snapshot("validate")
                self.assertEqual(result.returncode, status, result.stderr)
                path = self.snapshot_path(result, "clean")
                report = self.report_path(result)
                self.assertEqual((path / ".nuc-deploy-active").exists(), retained)
                self.assertEqual(self.report_rows(report, "state.tsv")[-1]["state"], "queued" if retained else "failed")
                if retained:
                    unit = (report / "unit.txt").read_text().strip()
                    self.assertEqual((path / ".nuc-deploy-active").read_text(), "systemd-user-unit=" + unit + "\n")

    def test_validation_on_the_actual_nuc_uses_local_transport_without_ssh(self):
        self.env.update(HEY_NUC_TEST_HOST="nuc", HEY_NUC_TEST_PLATFORM="Linux")
        result = self.snapshot("validate")
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.snapshot_path(result, "clean")
        report = self.report_path(result)
        self.assertEqual(self.commands("ssh"), [])
        self.assertEqual(self.commands("sudo"), [])
        self.assertEqual(self.report_rows(report, "state.tsv")[-1]["state"], "completed")
        self.assertFalse((path / ".nuc-deploy-active").exists())

    def test_validation_memory_preflight_cannot_start_evaluator_or_daemon_build_clients(self):
        self.meminfo.write_text("MemAvailable: 1000000 kB\n")
        result = self.snapshot("validate")
        self.assertEqual(result.returncode, 1, result.stderr)
        report = self.report_path(result)
        self.assertEqual([row["status"] for row in self.report_rows(report, "summary.tsv")], ["75", "75", "75"])
        self.assertEqual(self.commands("python3"), [])
        self.assertEqual(self.commands("nix"), [])
        self.assertFalse((self.snapshot_path(result, "clean") / ".nuc-deploy-active").exists())

    def test_pre_submission_render_failure_keeps_client_cleanup_until_the_lease_is_released(self):
        (self.root / "packages/hey/workers/nuc-validation.sh").unlink()
        result = self.snapshot("validate")
        self.assertNotEqual(result.returncode, 0)
        path = self.snapshot_path(result, "dirty")
        self.assertFalse((path / ".nuc-deploy-active").exists())
        self.assertEqual(self.commands("systemd-run"), [])

    def test_successful_validation_gates_cannot_hide_finalizer_cleanup_failure(self):
        (self.root / "bin/prune-nuc-deploy-snapshots").write_text(
            '#!/usr/bin/env bash\nif [ "$3" = 5 ]; then exit 23; fi\n')
        result = self.snapshot("validate")
        self.assertEqual(result.returncode, 1, result.stderr)
        report = self.report_path(result)
        self.assertEqual(self.report_rows(report, "result.tsv")[0]["outcome"], "success")
        self.assertEqual(self.report_rows(report, "state.tsv")[-1]["outcome"], "cleanup")
        self.assertFalse((self.snapshot_path(result, "dirty") / ".nuc-deploy-active").exists())

    def test_revision_target_must_be_nuc_on_linux_before_privilege_is_requested(self):
        for key, value in (("HEY_REMOTE_HOST", "wrong-host"), ("HEY_REMOTE_PLATFORM", "Darwin")):
            with self.subTest(key=key):
                self.env[key] = value
                result = self.run_task("nuc", "nuc", "revision", self.head)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.commands("sudo"), [])
                self.env.pop(key)


if __name__ == "__main__":
    unittest.main()
