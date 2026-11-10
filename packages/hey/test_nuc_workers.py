"""Exercise NUC worker effects only in disposable local filesystems."""

import base64
import csv
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

WORKERS = Path(__file__).resolve().parent / "workers"


class NucWorkerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey nuc worker ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / "snapshot source"
        self.report = self.root / "validation report"
        self.tools = self.root / "tools"
        for path in (self.source, self.report, self.tools):
            path.mkdir()
        self.env = os.environ | {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
        self.git = shutil.which("git")
        self.bash = shutil.which("bash")
        self.env["HEY_WORKER_ROOT"] = str(self.root)
        files = {"flake.nix": "{}\n", ".gitignore": "config/jj/\n.pi/\nignored.txt\n",
                 "config/jj/config.toml": "tracked ignored config\n", ".pi/tracked.txt": "tracked Pi source\n"}
        for name, text in files.items():
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git_run("init", "--quiet")
        self.git_run("-c", "core.excludesFile=/dev/null", "add", "-f", ".")
        self.digest = self.git_run("write-tree").stdout.strip()
        shutil.rmtree(self.source / ".git")
        self.lease = self.source / ".nuc-deploy-active"
        self.lease.write_text("active\n")
        (self.source / ".nuc-deploy-source-revision").write_text("1" * 40)
        self.meminfo = self.root / "meminfo"
        self.meminfo.write_text("MemTotal: 64000000 kB\nMemAvailable: 50000000 kB\n")
        self.unit = "nuc-validation-70000000-0000-0000-0000-000000000000.service"
        (self.report / "state.tsv").write_text("state\ttimestamp\tstatus\toutcome\tdetail\nqueued\tbefore\t\t\t\n")
        (self.report / "summary.tsv").write_text("gate\tstatus\tlog_status\tlog\n")
        common = "import json, os, pathlib, sys\nroot = pathlib.Path(os.environ['HEY_WORKER_ROOT'])\n"
        self.tool("gate-runner", common +
                  "gate = sys.argv[1]\n"
                  "with (root / 'gates.jsonl').open('a') as log:\n"
                  "    log.write(json.dumps([gate, os.environ.get('NIX_CONFIG'), os.getcwd()]) + '\\n')\n"
                  "print('gate output: ' + gate)\n"
                  "raise SystemExit({'full': 3, 'nixos': 0, 'flake-check': 5}[gate])\n")
        self.tool("flock", common + "(root / 'flock-called').write_text(json.dumps(sys.argv[1:]))\n")
        self.tool("systemctl", common +
                  "assert sys.argv[1] == '--user'\n"
                  "if sys.argv[2] == 'show': print(os.environ.get('HEY_UNIT_LOAD', 'not-found'))\n"
                  "elif sys.argv[2] == 'is-active': raise SystemExit(int(os.environ.get('HEY_UNIT_ACTIVE_EXIT', '3')))\n"
                  "else: raise SystemExit(92)\n")
        self.env["PATH"] = str(self.tools) + os.pathsep + os.environ["PATH"]
        self.release_command = shlex.join([self.bash, "-c", (WORKERS / "nuc-release.sh").read_text(), "--",
                                          str(self.source), "tester", str(self.root), "5", "exit 0"])

    def tool(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def git_run(self, *args):
        return subprocess.run([self.git, "-C", str(self.source), *args], env=self.env,
                              capture_output=True, text=True, check=True)

    def worker(self, name, *args):
        return subprocess.run([self.bash, str(WORKERS / name), *args], env=self.env,
                              cwd=self.root, capture_output=True, text=True, timeout=15)

    def validation(self, digest=None, gates=None):
        if gates is None:
            gates = [item for name in ("full", "nixos", "flake-check") for item in (name, "2", "gate-runner", name)]
        return self.worker("nuc-validation.sh", str(self.source), digest or self.digest, str(self.report),
                           str(self.meminfo), str(16 * 1024 * 1024), "max-jobs = 1\ncores = 2",
                           str(self.root / "validation.lock"), *gates)

    def rows(self, name):
        with (self.report / name).open() as file:
            return list(csv.DictReader(file, delimiter="\t"))

    def finalizer(self, release=None):
        return self.worker("nuc-validation-finalizer.sh", str(self.report), release or self.release_command)

    def submission(self, service="exit 42", release=None):
        encoded = base64.b64encode(service.encode()).decode()
        return self.worker("nuc-validation-submission.sh", str(self.source), "1" * 40, self.digest,
                           str(self.report), self.unit, encoded, release or self.release_command,
                           "user service: MemoryHigh=10G MemoryMax=12G")

    def test_gates_all_run_and_failures_are_durable_after_exact_git_reconstruction(self):
        result = self.validation()
        self.assertEqual(result.returncode, 1, result.stderr)
        rows = self.rows("summary.tsv")
        self.assertEqual([(row["gate"], row["status"], row["log_status"]) for row in rows],
                         [("full", "3", "0"), ("nixos", "0", "0"), ("flake-check", "5", "0")])
        calls = [json.loads(line) for line in (self.root / "gates.jsonl").read_text().splitlines()]
        self.assertEqual([call[0] for call in calls], ["full", "nixos", "flake-check"])
        self.assertTrue(all(call[1] == "max-jobs = 1\ncores = 2" and call[2] == str(self.source) for call in calls))
        self.assertEqual(self.git_run("rev-parse", "HEAD^{tree}").stdout.strip(), self.digest)
        self.assertEqual(self.git_run("config", "core.hooksPath").stdout.strip(), "/dev/null")
        self.assertEqual(self.git_run("ls-files", "config/jj/config.toml", ".pi/tracked.txt").stdout.splitlines(),
                         [".pi/tracked.txt", "config/jj/config.toml"])
        self.assertTrue((self.root / "flock-called").exists())
        self.assertIn("NUC_VALIDATION_REPORT_DIR=", result.stdout)
        self.assertEqual(self.rows("result.tsv")[0]["outcome"], "gates")
        finalized = self.finalizer()
        self.assertEqual(finalized.returncode, 1, finalized.stderr)
        self.assertEqual([row["state"] for row in self.rows("state.tsv")], ["queued", "running", "failed"])
        self.assertEqual(self.rows("state.tsv")[-1]["outcome"], "gates")
        self.assertFalse(self.lease.exists())

    def test_low_memory_cannot_start_any_gate(self):
        self.meminfo.write_text("MemAvailable: 1000000 kB\n")
        result = self.validation()
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.root / "gates.jsonl").exists())
        self.assertEqual([row["status"] for row in self.rows("summary.tsv")], ["75", "75", "75"])
        self.assertIn("gate not started because its host memory preflight failed", (self.report / "full.log").read_text())

    def test_bad_digest_records_setup_failure_and_never_starts_a_gate(self):
        result = self.validation(digest="0" * 40)
        self.assertEqual(result.returncode, 1)
        record = self.rows("result.tsv")[0]
        self.assertEqual(record["outcome"], "setup")
        self.assertIn("snapshot digest mismatch", record["detail"])
        self.assertFalse((self.root / "gates.jsonl").exists())
        self.assertEqual(self.finalizer().returncode, 1)
        self.assertEqual(self.rows("state.tsv")[-1]["outcome"], "setup")

    def test_empty_and_malformed_gate_plans_cannot_report_success(self):
        for gates in ([], ["full", "2", "gate-runner"], ["../escape", "2", "gate-runner", "full"]):
            with self.subTest(gates=gates):
                result = self.validation(gates=gates)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.rows("result.tsv")[0]["outcome"], "setup")
                self.assertFalse((self.root / "gates.jsonl").exists())
                self.assertFalse((self.root / "escape.log").exists())

    def test_log_writer_failure_is_distinct_from_gate_status(self):
        self.tool("tee", "import sys\nsys.stdin.buffer.read()\nraise SystemExit(12)\n")
        result = self.validation()
        self.assertEqual(result.returncode, 1)
        self.assertEqual([row["log_status"] for row in self.rows("summary.tsv")], ["12", "12", "12"])
        self.assertEqual(self.rows("result.tsv")[0]["outcome"], "logging")

    def test_successful_gates_still_fail_when_final_cleanup_fails(self):
        (self.report / "result.tsv").write_text("outcome\tstatus\tdetail\nsuccess\t0\tall gates passed\n")
        result = self.finalizer("exit 23")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.rows("state.tsv")[-1]["outcome"], "cleanup")

    def test_interrupted_service_has_a_durable_terminal_state_and_releases_lease(self):
        self.env.update(SERVICE_RESULT="signal", EXIT_CODE="killed", EXIT_STATUS="TERM")
        result = self.finalizer()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.rows("state.tsv")[-1]["outcome"], "interrupted")
        self.assertFalse(self.lease.exists())

    def test_definitely_rejected_submission_releases_lease_and_records_provenance(self):
        result = self.submission()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.report / "unit.txt").read_text().strip(), self.unit)
        self.assertEqual(self.rows("state.tsv")[-1]["outcome"], "submission")
        provenance = (self.report / "provenance.txt").read_text()
        self.assertIn("content_digest=git-tree:" + self.digest, provenance)
        self.assertIn("evaluator_memory_boundary=user service: MemoryHigh=10G MemoryMax=12G", provenance)
        self.assertIn("builder_memory_boundary=none: system nix-daemon builders and KVM guests run outside the user service cgroup", provenance)
        self.assertFalse(self.lease.exists())

    def test_uncertain_submission_preserves_service_owned_snapshot(self):
        self.env.update(HEY_UNIT_LOAD="loaded", HEY_UNIT_ACTIVE_EXIT="1")
        result = self.submission()
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertEqual(self.lease.read_text(), "systemd-user-unit=" + self.unit + "\n")
        self.assertEqual(self.rows("state.tsv")[-1]["state"], "queued")

    def test_lifecycle_preserves_command_failure_even_if_cleanup_also_fails(self):
        for command_status, cleanup_status, expected in ((0, 0, 0), (0, 23, 1), (7, 23, 7)):
            with self.subTest(command=command_status, cleanup=cleanup_status):
                result = self.worker("nuc-lifecycle.sh", str(self.source), f"exit {cleanup_status}",
                                     self.bash, "-c", f"exit {command_status}")
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_release_removes_lease_even_if_pruning_fails(self):
        result = self.worker("nuc-release.sh", str(self.source), "tester", str(self.root), "5", "exit 22")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(self.lease.exists())


if __name__ == "__main__":
    unittest.main()
