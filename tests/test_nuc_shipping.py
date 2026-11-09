"""Real CLI/receipt and workflow shell tests; only GitHub and sleep are simulated."""

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/nuc_shipping.py"
SHA = "a" * 40
CI_SUCCESS = {
    "id": 41,
    "run_attempt": 2,
    "path": ".github/workflows/ci.yml",
    "head_sha": SHA,
    "head_branch": "main",
    "event": "push",
    "status": "completed",
    "conclusion": "success",
}

GITHUB_STUB = r"""
import json, os, sys
from pathlib import Path
from urllib.parse import urlparse, parse_qs
root = Path(os.environ["GITHUB_FIXTURE"])
state = json.loads((root / "github.json").read_text())
args = sys.argv[1:]
assert args[0] == "api", args
endpoint = args[1]
path = urlparse(endpoint).path
query = parse_qs(urlparse(endpoint).query)
if state.get("auth_error"):
    sys.exit("authentication unavailable")
if path == "user":
    result = {"login": "shipper"}
elif path.endswith("git/ref/heads/main"):
    if "--jq" in args:
        print(state["main"])
        sys.exit(0)
    result = {"object": {"sha": state["main"]}}
elif path.endswith("ci.yml/runs"):
    # Request submission must not look up CI; only the workflow may do so.
    assert os.environ.get("WORKFLOW_TEST") == "1"
    assert query == {"branch": ["main"], "event": ["push"],
                     "head_sha": ["a" * 40], "per_page": ["1"]}
    counter = root / "ci_reads"
    index = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(index + 1))
    responses = state["ci_responses"]
    result = responses[min(index, len(responses) - 1)]
elif path.endswith("deploy-nuc.yml/dispatches"):
    payload = json.load(sys.stdin)
    inputs = {"expected_sha": "a" * 40}
    if state.get("orb_pilot"):
        inputs["orb_pilot"] = "true"
    if state.get("recover_orb_pilot"):
        inputs["recover_orb_pilot"] = "true"
    if state.get("ha_monitor"):
        inputs["ha_monitor"] = "true"
    assert payload == {"ref": "main", "inputs": inputs}
    with (root / "dispatches").open("a") as out:
        out.write(json.dumps(payload) + "\n")
    if state.get("kill_owner"):
        import signal
        os.kill(os.getppid(), signal.SIGKILL)
    if state.get("dispatch_error"):
        sys.exit("connection lost after possible acceptance")
    sys.exit(0)
elif path.endswith("deploy-nuc.yml/runs"):
    result = [{"workflow_runs": state.get("deploy_runs", [])}]
else:
    sys.exit("unexpected endpoint " + endpoint)
print(json.dumps(result))
"""


class NucShippingTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.receipt = self.root / "receipt.json"
        self.receipt.write_text(
            json.dumps(
                {
                    "schemaVersion": 2,
                    "status": "active",
                    "authority": {"mode": "full"},
                    "closeout": {"evidence": {"keep": 17}},
                }
            )
        )
        self.github = {"main": SHA, "ci_responses": [{"workflow_runs": []}]}
        self.save_github()
        stub = self.root / "gh"
        stub.write_text(f"#!{sys.executable}\n" + GITHUB_STUB)
        stub.chmod(0o755)
        self.env = os.environ | {
            "PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}",
            "GITHUB_FIXTURE": str(self.root),
        }

    def save_github(self):
        (self.root / "github.json").write_text(json.dumps(self.github))

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--receipt", str(self.receipt), *args],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def request(self, *args):
        return self.cli(
            "request",
            "--sha",
            SHA,
            "--thread",
            "owner-thread",
            "--deployment-authority",
            "explicit deployment authorization",
            *args,
        )

    def test_request_before_ci_and_concurrent_replay_submit_once(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.request(), range(2)))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len((self.root / "dispatches").read_text().splitlines()), 1)
        self.assertFalse((self.root / "ci_reads").exists())
        receipt = json.loads(self.receipt.read_text())
        self.assertEqual(receipt["closeout"]["evidence"], {"keep": 17})
        self.assertEqual(receipt["status"], "active")
        self.assertEqual(receipt["nucShipping"]["state"], "dispatched")
        self.assertNotEqual(self.request("--no-deploy").returncode, 0)

    def test_pilot_checks_are_opt_in_and_cannot_change_on_replay(self):
        self.github["orb_pilot"] = True
        self.save_github()
        result = self.request("--orb-pilot")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["orbPilot"])
        self.assertEqual(self.request("--orb-pilot").returncode, 0)
        self.assertNotEqual(self.request().returncode, 0)
        requests = (self.root / "dispatches").read_text().splitlines()
        self.assertEqual(len(requests), 1)
        self.assertEqual(json.loads(requests[0])["inputs"]["orb_pilot"], "true")

    def test_pilot_recovery_requires_checks_and_cannot_change_on_replay(self):
        self.assertNotEqual(self.request("--recover-orb-pilot").returncode, 0)
        self.assertFalse((self.root / "dispatches").exists())
        self.github.update(orb_pilot=True, recover_orb_pilot=True)
        self.save_github()
        result = self.request("--orb-pilot", "--recover-orb-pilot")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["recoverOrbPilot"])
        self.assertNotEqual(self.request("--orb-pilot").returncode, 0)
        self.assertEqual(self.request("--orb-pilot", "--recover-orb-pilot").returncode, 0)
        self.assertEqual(len((self.root / "dispatches").read_text().splitlines()), 1)

    def test_ha_monitor_setup_is_opt_in_and_cannot_change_on_replay(self):
        self.github["ha_monitor"] = True
        self.save_github()
        result = self.request("--ha-monitor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["haMonitor"])
        self.assertNotEqual(self.request().returncode, 0)
        self.assertEqual(self.request("--ha-monitor").returncode, 0)
        self.assertEqual(len((self.root / "dispatches").read_text().splitlines()), 1)

    def test_no_deploy_is_offline_and_cannot_be_rearmed_by_replay(self):
        self.github["auth_error"] = True
        self.save_github()
        result = self.cli(
            "request", "--sha", SHA, "--thread", "owner-thread", "--no-deploy"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "skipped")
        self.assertNotEqual(self.request().returncode, 0)
        self.assertFalse((self.root / "dispatches").exists())

    def test_missing_authority_push_only_and_moved_main_reject_requests(self):
        result = self.cli("request", "--sha", SHA, "--thread", "owner-thread")
        self.assertNotEqual(result.returncode, 0)
        receipt = json.loads(self.receipt.read_text())
        receipt["authority"]["mode"] = "commit-push"
        self.receipt.write_text(json.dumps(receipt))
        self.assertNotEqual(self.request().returncode, 0)
        receipt["authority"]["mode"] = "full"
        self.receipt.write_text(json.dumps(receipt))
        self.github["main"] = "b" * 40
        self.save_github()
        self.assertNotEqual(self.request().returncode, 0)
        self.assertFalse((self.root / "dispatches").exists())

    def test_uncertain_dispatch_reconciles_raced_run_without_retry(self):
        self.github["dispatch_error"] = True
        self.save_github()
        self.assertNotEqual(self.request().returncode, 0)
        claim = json.loads(self.receipt.read_text())["nucShipping"]
        self.assertEqual(claim["state"], "dispatch_unknown")
        self.assertEqual(self.cli("reconcile").returncode, 0)
        match = {
            "id": 91,
            "display_title": f"Deploy NUC {SHA}",
            "actor": {"login": "shipper"},
            "event": "workflow_dispatch",
            "created_at": claim["dispatchStartedAt"],
            "head_sha": "b" * 40,
            "html_url": "https://github.com/edmundmiller/dotfiles/actions/runs/91",
        }
        self.github.update(main="b" * 40, deploy_runs=[match, match | {"id": 92}])
        self.save_github()
        self.cli("reconcile")
        self.assertNotIn(
            "deploymentRunId", json.loads(self.receipt.read_text())["nucShipping"]
        )
        self.github["deploy_runs"] = [
            match,
            match | {"actor": {"login": "other"}},
            match | {"created_at": "2000-01-01T00:00:00Z"},
            match | {"display_title": "Deploy NUC " + "c" * 40},
        ]
        self.save_github()
        self.assertEqual(self.cli("reconcile").returncode, 0)
        self.assertEqual(
            json.loads(self.receipt.read_text())["nucShipping"]["deploymentRunId"], 91
        )
        self.assertEqual(len((self.root / "dispatches").read_text().splitlines()), 1)

    def test_auth_failure_can_retry_but_process_death_preserves_dispatch_claim(self):
        self.github["auth_error"] = True
        self.save_github()
        self.assertNotEqual(self.request().returncode, 0)
        self.assertEqual(
            json.loads(self.receipt.read_text())["nucShipping"]["state"],
            "request_pending",
        )
        self.github.update(auth_error=False, kill_owner=True)
        self.save_github()
        self.assertLess(self.request().returncode, 0)
        self.assertEqual(
            json.loads(self.receipt.read_text())["nucShipping"]["state"],
            "dispatch_unknown",
        )
        self.assertEqual(self.request().returncode, 0)
        self.assertEqual(len((self.root / "dispatches").read_text().splitlines()), 1)

    def workflow_shell(self, step, setup="sleep() { :; };\n"):
        workflow = (ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        shell = textwrap.dedent(
            workflow.split(f"      - name: {step}\n", 1)[1]
            .split("        run: |\n", 1)[1]
            .split("\n  deploy:", 1)[0]
            .split("      - ", 1)[0]
        )
        return subprocess.run(
            ["bash", "-c", setup + shell],
            env=self.env | {"WORKFLOW_TEST": "1", "DEPLOY_SHA": SHA},
            capture_output=True,
            text=True,
            timeout=20,
        )

    def test_workflow_waits_for_missing_and_running_ci_then_succeeds(self):
        self.github["ci_responses"] = [
            {"workflow_runs": []},
            {
                "workflow_runs": [
                    CI_SUCCESS
                    | {"run_attempt": 3, "status": "in_progress", "conclusion": None},
                    CI_SUCCESS,
                ]
            },
            {"workflow_runs": [CI_SUCCESS | {"run_attempt": 3}]},
        ]
        self.save_github()
        result = self.workflow_shell("Wait for exact-main CI in GitHub")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "ci_reads").read_text(), "3")

    def test_workflow_rejects_bad_results_and_never_uses_old_success(self):
        for changed in (
            {"conclusion": "failure"},
            {"conclusion": "cancelled"},
            {"conclusion": "skipped"},
            {"head_sha": "b" * 40},
            {"event": "pull_request"},
            {"head_branch": "topic"},
            {"path": ".github/workflows/other.yml"},
            {"status": None},
        ):
            with self.subTest(changed=changed):
                self.github["ci_responses"] = [
                    {"workflow_runs": [CI_SUCCESS | changed, CI_SUCCESS]}
                ]
                self.save_github()
                self.assertNotEqual(
                    self.workflow_shell("Wait for exact-main CI in GitHub").returncode,
                    0,
                )
        for response in ({}, {"workflow_runs": None}):
            self.github["ci_responses"] = [response]
            self.save_github()
            self.assertNotEqual(
                self.workflow_shell("Wait for exact-main CI in GitHub").returncode, 0
            )

    def test_workflow_timeout_main_move_and_post_wait_rerun_fail_closed(self):
        # Accelerate only the clock. Exercise all 180 production loop iterations.
        result = self.workflow_shell("Wait for exact-main CI in GitHub")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timed out", result.stderr)
        self.assertEqual((self.root / "ci_reads").read_text(), "180")
        self.github["main"] = "b" * 40
        self.save_github()
        result = self.workflow_shell("Wait for exact-main CI in GitHub")
        self.assertIn("main moved", result.stderr)
        self.assertNotEqual(result.returncode, 0)
        # The deploy job's original final check must reject a rerun starting
        # after the waiting job passed, and accept the positive control.
        self.github["main"] = SHA
        for status, conclusion, accepted in (
            ("completed", "success", True),
            ("in_progress", None, False),
            ("completed", "failure", False),
        ):
            self.github["ci_responses"] = [
                {
                    "workflow_runs": [
                        CI_SUCCESS | {"status": status, "conclusion": conclusion}
                    ]
                }
            ]
            self.save_github()
            result = self.workflow_shell(
                "Require successful main CI for this exact commit"
            )
            self.assertEqual(result.returncode == 0, accepted, result.stderr)

    def test_only_explicit_requests_can_reach_privileged_deployment(self):
        for requested, accepted in (
            (SHA, True),
            ("b" * 40, False),
            ("a" * 39, False),
            ("A" * 40, False),
            ("", False),
        ):
            with self.subTest(requested=requested):
                result = self.workflow_shell(
                    "Require requested deployment revision",
                    setup=f'export EXPECTED_SHA="{requested}"\n',
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
        workflow = (ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        triggers = workflow.split("on:\n", 1)[1].split("permissions:", 1)[0]
        self.assertIn("workflow_dispatch:", triggers)
        for automatic in ("workflow_run:", "push:", "schedule:", "pull_request:"):
            self.assertNotIn(automatic, triggers)
        waiting, deployment = workflow.split("\n  deploy:\n", 1)
        for privileged in (
            "id-token: write",
            "environment: nuc",
            "uses: actions/checkout",
            "uses: tailscale/",
        ):
            self.assertNotIn(privileged, waiting)
            self.assertIn(privileged, deployment)
        self.assertIn("needs: wait-for-ci", deployment)
        self.assertNotIn("always()", deployment)
        self.assertIn("inputs.expected_sha", deployment)
        self.assertIn("mise run nuc revision", deployment)
        for name in (
            "Fetch, build, activate and verify on the NUC",
            "Record deployed revision",
        ):
            self.assertIn(
                f"- name: {name}\n        if: inputs.operation == 'deploy'\n",
                deployment,
            )
        for name in (
            "Check live orb pilot capacity before activation",
            "Verify live orb pilot backend",
        ):
            self.assertIn(
                f"- name: {name}\n"
                "        if: inputs.operation == 'deploy' && inputs.orb_pilot\n",
                deployment,
            )
        self.assertIn(
            "- name: Restart Bluetooth once and allow automatic HA retry\n"
            "        if: inputs.operation == 'ha-diagnostics' && inputs.restart_bluetooth\n",
            deployment,
        )
        self.assertIn("default: false", triggers.split("restart_bluetooth:", 1)[1])
        self.assertIn("default: false", triggers.split("ha_monitor:", 1)[1])
        for name in (
            "Configure approved HA heartbeat before activation",
            "Allow two automatic HA monitor runs",
        ):
            self.assertIn(
                f"- name: {name}\n"
                "        if: inputs.operation == 'deploy' && inputs.ha_monitor\n",
                deployment,
            )
        self.assertIn(
            "- name: Release inherited pilot locks before activation\n"
            "        if: inputs.operation == 'deploy' && inputs.recover_orb_pilot\n",
            deployment,
        )

    def test_bluetooth_recovery_checks_host_and_preserves_ha_process(self):
        setup = r"""
            sleep() { :; }
            tailscale() { bash -c "$3"; }
            hostname() { printf '%s\n' "$TARGET_HOST"; }
            nixos-version() { printf 'unchanged-revision\n'; }
            systemctl() {
              case "$*" in
                'show home-assistant.service -p MainPID --value')
                  cat "$GITHUB_FIXTURE/ha-pid" ;;
                'show bluetooth.service -p MainPID -p ActiveEnterTimestamp')
                  printf 'MainPID=%s\n' "$(cat "$GITHUB_FIXTURE/bluetooth-pid")" ;;
                'is-active --quiet home-assistant.service'|'is-active --quiet bluetooth.service')
                  return 0 ;;
                *) return 77 ;;
              esac
            }
            sudo() {
              test "$*" = '-n systemctl restart bluetooth.service' || return 78
              pid=$(cat "$GITHUB_FIXTURE/bluetooth-pid")
              printf '%s\n' "$((pid + 1))" > "$GITHUB_FIXTURE/bluetooth-pid"
              if test "$CHANGE_HA_PID" = true; then
                printf '201\n' > "$GITHUB_FIXTURE/ha-pid"
              fi
            }
            export -f hostname nixos-version systemctl sudo
        """
        for host, change_ha, accepted in (
            ("nuc", "false", True),
            ("another-host", "false", False),
            ("nuc", "true", False),
        ):
            with self.subTest(host=host, change_ha=change_ha):
                (self.root / "bluetooth-pid").write_text("100\n")
                (self.root / "ha-pid").write_text("200\n")
                result = self.workflow_shell(
                    "Restart Bluetooth once and allow automatic HA retry",
                    setup=textwrap.dedent(setup)
                    + f'export TARGET_HOST="{host}" CHANGE_HA_PID="{change_ha}"\n',
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
                self.assertEqual(
                    (self.root / "bluetooth-pid").read_text(),
                    "101\n" if host == "nuc" else "100\n",
                )
                if change_ha == "false":
                    self.assertEqual((self.root / "ha-pid").read_text(), "200\n")

    def test_diagnostics_preserve_unhealthy_and_unknown_results_without_activation(self):
        workflow = (ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        self.assertIn(
            "- name: Inspect running HA without activation\n"
            "        if: inputs.operation == 'ha-diagnostics'\n",
            workflow,
        )
        for code, status in ((0, "healthy"), (1, "unhealthy"), (2, "unknown")):
            with self.subTest(status=status):
                report = {
                    "schema_version": 1,
                    "status": status,
                    "checks": {"repairs": {"issues": [{"issue_id": "backup_repair"}]}},
                }
                setup = (
                    f'export RUNNER_TEMP="{self.root}"\n'
                    f'export GITHUB_STEP_SUMMARY="{self.root / "summary"}"\n'
                    "tailscale() { cat > /dev/null; "
                    f"printf '%s\\n' '{json.dumps(report)}'; return {code}; }}\n"
                )
                result = self.workflow_shell(
                    "Inspect running HA without activation", setup=setup
                )
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertEqual(json.loads(result.stdout), report)
                self.assertIn("backup_repair", (self.root / "summary").read_text())


class HaMonitorTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.key = Path(temp.name) / "key"
        self.key.write_text("private-api-key")
        self.now = datetime.now(UTC)
        self.check = {
            "uuid": "monitor", "name": "nuc/ha-runtime", "slug": "nuc-ha-runtime",
            "timeout": 300, "grace": 300, "channels": "intended",
            "status": "up", "n_pings": 2, "last_ping": self.now.isoformat(),
        }
        self.exists = False
        self.channels = "intended"
        self.api_failure_path = None
        self.writes = []
        self.pings = [
            {"type": "success", "date": (self.now - timedelta(seconds=seconds)).isoformat(),
             "body_url": None, "remote_addr": "private-address"}
            for seconds in (0, 120)
        ]
        self.reports = [
            {"schema_version": 1, "observed_at": (self.now - timedelta(seconds=seconds + 1)).isoformat(),
             "status": "healthy", "checks": {"repairs": {"status": "healthy", "issues": ["private-HA-report"]}}}
            for seconds in (120, 0)
        ]
        self.timer_active = True

    def api(self, req, **_kwargs):
        path = req.full_url.removeprefix("https://healthchecks.io/api/v3")
        if path == self.api_failure_path:
            raise HTTPError(req.full_url, 403, "private-reason", {}, io.BytesIO(b"private-response"))
        if req.data is not None:
            self.assertEqual(path, "/checks/")
            self.writes.append(json.loads(req.data))
            self.exists = True
            result = self.check
        elif path == "/checks/a6bbb4df-b118-4262-9881-9939f3ac7e76":
            result = {"channels": self.channels}
        elif path == "/channels/":
            result = {"channels": [{"id": "intended", "kind": "email"}, {"id": "unrelated", "kind": "sms"}]}
        elif path == "/checks/?slug=nuc-ha-runtime":
            result = {"checks": [self.check] if self.exists else []}
        elif path == "/checks/monitor/pings/":
            result = {"pings": self.pings}
        elif path.startswith("/checks/monitor/flips/?start="):
            result = []
        else:
            self.fail(f"Unexpected request path: {path}")
        return io.StringIO(json.dumps(result))

    def command(self, args, **_kwargs):
        if args[0] == "journalctl":
            return subprocess.CompletedProcess(args, 0, "\n".join(map(json.dumps, self.reports)))
        self.assertEqual(args, ["systemctl", "is-active", "--quiet", "hass-health.timer"])
        return subprocess.CompletedProcess(args, 0 if self.timer_active else 3)

    def invoke(self, action, *extra):
        output = io.StringIO()
        with patch("urllib.request.urlopen", side_effect=self.api), patch("subprocess.run", side_effect=self.command), patch("sys.stdout", output), patch("sys.argv", ["monitor-healthchecks.py", action, "--api-key-file", str(self.key), *extra]):
            with self.assertRaises(SystemExit) as exit_status:
                runpy.run_path(str(ROOT / "modules/services/hass/monitor-healthchecks.py"), run_name="__main__")
        self.assertNotIn("private", output.getvalue())
        return exit_status.exception.code, json.loads(output.getvalue())

    def test_setup_inherits_only_intended_channels_and_replay_does_not_write(self):
        code, report = self.invoke("setup")
        self.assertEqual(code, 0)
        self.assertEqual(report["notification_channel_kinds"], ["email"])
        self.assertEqual(len(self.writes), 1)
        self.assertEqual(self.writes[0]["channels"], "intended")
        self.assertEqual(self.writes[0]["unique"], ["slug"])
        self.assertEqual(self.writes[0]["timeout"], 300)
        self.assertEqual(self.writes[0]["grace"], 300)
        self.assertEqual(self.invoke("setup")[0], 0)
        self.assertEqual(len(self.writes), 1)

    def test_missing_channels_or_conflicting_settings_fail_without_writes(self):
        self.channels = ""
        self.assertEqual(self.invoke("setup")[0], 2)
        self.channels = "intended"
        self.exists = True
        self.check["timeout"] = 86400
        self.assertEqual(self.invoke("setup")[0], 2)
        self.assertEqual(self.writes, [])

    def test_live_verification_requires_recent_reports_pings_and_active_timer(self):
        self.exists = True
        code, report = self.invoke("status", "--require-live")
        self.assertEqual(code, 0)
        self.assertEqual(report["ping_report_correlation"], {"success_healthy": 2})
        self.assertEqual(report["journal"]["statuses"], {"healthy": 2})
        self.timer_active = False
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.timer_active = True
        self.pings[0]["body_url"] = "private-body-url"
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.pings[0]["body_url"] = None
        self.pings[1]["date"] = (self.now - timedelta(minutes=6)).isoformat()
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.assertEqual(self.writes, [])

    def test_failure_reports_safe_cause_and_prior_monitor_presence_without_writes(self):
        for path, phase, exists in (
            ("/checks/?slug=nuc-ha-runtime", "find_monitor", None),
            ("/checks/a6bbb4df-b118-4262-9881-9939f3ac7e76", "read_reference_check", True),
        ):
            with self.subTest(phase=phase):
                self.exists = True
                self.api_failure_path = path
                code, report = self.invoke("status")
                self.assertEqual(code, 2)
                self.assertEqual(report["phase"], phase)
                self.assertEqual(report["http_status"], 403)
                self.assertEqual(report["monitor_existed_before_setup"], exists)
        self.key.unlink()
        code, report = self.invoke("status")
        self.assertEqual(code, 2)
        self.assertEqual(report["phase"], "read_api_key")
        self.assertEqual(report["error_type"], "FileNotFoundError")
        self.assertIsNone(report["http_status"])
        self.assertEqual(self.writes, [])

    def test_signal_correlation_distinguishes_false_alarms_and_coverage_gaps(self):
        self.exists = True
        self.pings[0]["type"] = "fail"
        self.pings[1]["date"] = (self.now - timedelta(minutes=4)).isoformat()
        code, report = self.invoke("status")
        self.assertEqual(code, 0)
        self.assertEqual(report["ping_report_correlation"], {"fail_healthy": 1, "success_uncorrelated": 1})
        self.reports[-1]["status"] = "unhealthy"
        self.reports[-1]["checks"]["integrations"] = {"status": "unhealthy"}
        _, report = self.invoke("status")
        self.assertEqual(report["ping_report_correlation"]["fail_unhealthy"], 1)
        self.assertEqual(report["journal"]["failing_checks"], {"integrations": 1})
        self.assertEqual(self.writes, [])


if __name__ == "__main__":
    unittest.main()
