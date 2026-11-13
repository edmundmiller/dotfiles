"""Real CLI/receipt and workflow shell tests; only GitHub and sleep are simulated."""

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
import io
import json
import os
from pathlib import Path
import runpy
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError
from urllib.request import urlopen
from zoneinfo import ZoneInfo

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
            # A hang guard, not a speed check on a loaded machine.
            timeout=120,
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
        # Avoid starting Python twice per iteration while exercising the real
        # workflow loop and jq expression against a perpetually pending run.
        setup = r'''
sleep() { [[ "$*" == "30" ]] || return 1; printf x >> "$GITHUB_FIXTURE/sleeps"; }
gh() {
    if [[ "$*" == "api repos/edmundmiller/dotfiles/git/ref/heads/main --jq .object.sha" ]]; then
        printf '%s\n' "$DEPLOY_SHA"
    elif [[ "$*" == "api repos/edmundmiller/dotfiles/actions/workflows/ci.yml/runs?branch=main&event=push&head_sha=$DEPLOY_SHA&per_page=1" ]]; then
        printf x >> "$GITHUB_FIXTURE/ci_reads"
        printf '%s\n' '{"workflow_runs": []}'
    else
        echo "unexpected gh arguments: $*" >&2
        return 1
    fi
}
'''
        result = self.workflow_shell("Wait for exact-main CI in GitHub", setup=setup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timed out", result.stderr)
        self.assertEqual((self.root / "ci_reads").read_text(), "x" * 180)
        self.assertEqual((self.root / "sleeps").read_text(), "x" * 179)
        (self.root / "ci_reads").unlink()
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
            "Configure approved HA monitor before activation",
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

    def test_climate_diagnostics_is_isolated_and_preserves_read_failures(self):
        name = "Inspect climate mapping and categorized retained errors without activation"
        workflow = (ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        self.assertIn(f"- name: {name}\n        if: inputs.operation == 'ha-climate-diagnostics'\n", workflow)
        self.assertIn("          - ha-climate-diagnostics\n", workflow)
        sudo = self.root / "sudo"
        sudo.write_text(
            f"#!{sys.executable}\n"
            "import os, sys\n"
            "assert sys.argv[1:] == ['-n', 'uv', 'run', '--no-project', '--script', '-']\n"
            "sys.stdin.read()\n"
            "print('{\"mapping\":{\"entity_id\":\"climate.master_suite\"}}')\n"
            "sys.exit(int(os.environ['READ_CODE']))\n"
        )
        sudo.chmod(0o755)
        setup = r"""
            tailscale() { bash -c "$3"; }
            hostname() { printf '%s\n' "$TARGET_HOST"; }
            nixos-version() { printf 'unchanged-revision\n'; }
            export -f hostname nixos-version
        """
        for host, code in (("nuc", 0), ("nuc", 2), ("another-host", 0)):
            with self.subTest(host=host, code=code):
                result = self.workflow_shell(name, setup=textwrap.dedent(setup) + f'export TARGET_HOST="{host}" READ_CODE={code}\n')
                self.assertEqual(result.returncode, code if host == "nuc" else 1, result.stderr)
                if host == "nuc":
                    self.assertEqual(json.loads(result.stdout)["mapping"]["entity_id"], "climate.master_suite")
                    self.assertIn("unchanged-revision", result.stderr)
                else:
                    self.assertEqual(result.stdout, "")

    def test_recurrence_workflow_transports_only_bounded_read_arguments(self):
        name = "Inspect one bounded climate recurrence without activation"
        workflow = (ROOT / ".github/workflows/deploy-nuc.yml").read_text()
        self.assertIn(f"- name: {name}\n        if: inputs.operation == 'ha-climate-recurrence'\n", workflow)
        self.assertIn("ping: ${{ inputs.operation != 'ha-climate-recurrence' &&", workflow)
        sudo = self.root / "sudo"
        sudo.write_text(
            f"#!{sys.executable}\n"
            "import os, sys\n"
            "assert sys.argv[1:] == ['-n', 'uv', 'run', '--no-project', '--script', '-', "
            "'--incident-start', os.environ['INCIDENT_START'], '--incident-cutoff', os.environ['INCIDENT_CUTOFF'], "
            "'--recovered-at', os.environ['RECOVERED_AT']]\n"
            "sys.stdin.read()\n"
            "print('{\"snapshot\":1}')\n"
            "sys.exit(int(os.environ['READ_CODE']))\n"
        )
        sudo.chmod(0o755)
        setup = r"""
            tailscale() { bash -c "$3"; }
            hostname() { printf '%s\n' "$TARGET_HOST"; }
            nixos-version() { printf 'unchanged-revision\n'; }
            export -f hostname nixos-version
        """
        self.env.update(INCIDENT_START="2026-11-01T06:59:00.123456Z", INCIDENT_CUTOFF="2026-11-01T07:12:00+00:00", RECOVERED_AT="")
        for host, code in (("nuc", 0), ("nuc", 2), ("another-host", 0)):
            with self.subTest(host=host, code=code):
                result = self.workflow_shell(name, setup=textwrap.dedent(setup) + f'export TARGET_HOST="{host}" READ_CODE={code}\n')
                self.assertEqual(result.returncode, code if host == "nuc" else 1, result.stderr)
                self.assertEqual(result.stdout, '{"snapshot":1}\n' if host == "nuc" else "")
        for start, cutoff, recovered in (("", "2026-11-01T07:12:00Z", ""),
                                         ("2026-11-01T06:59:00Z", "2026-11-01T07:12:00Z", "'; exit 0 #")):
            self.env.update(INCIDENT_START=start, INCIDENT_CUTOFF=cutoff, RECOVERED_AT=recovered)
            result = self.workflow_shell(name, setup="tailscale() { echo unexpected-host-read; };\n")
            self.assertEqual((result.returncode, result.stdout), (2, ""))


class CriticalEntityHistoryTests(unittest.TestCase):
    def invoke(self, lines=(), error=None):
        output = io.StringIO()
        journal = subprocess.CompletedProcess(
            [], 0, "private journal text\n" + "\n".join(map(json.dumps, lines))
        )
        with patch("subprocess.run", return_value=journal, side_effect=error), patch("sys.stdout", output):
            with self.assertRaises(SystemExit) as exit_status:
                runpy.run_path(str(ROOT / "modules/services/hass/critical-entity-history.py"), run_name="__main__")
        self.assertNotIn("private", output.getvalue())
        return exit_status.exception.code, json.loads(output.getvalue())

    def test_only_bounded_allowlisted_entity_failures_leave_the_host(self):
        def report(at, status, failures=()):
            return {
                "schema_version": 1, "observed_at": at,
                "checks": {
                    "critical_entities": {"status": status, "failures": list(failures)},
                    "repairs": {"details": "private repair"},
                },
            }

        code, result = self.invoke([
            report("2026-11-10T02:51:58Z", "unhealthy", [{"entity_id": "climate.main_floor", "state": "missing"}]),
            report("2026-11-10T16:59:00Z", "healthy"),
            report("2026-11-10T06:21:00Z", "unhealthy", [
                {"entity_id": "climate.master_suite", "state": "unavailable", "attributes": "private attributes"},
                {"entity_id": "private.person", "state": "unavailable"},
                {"entity_id": "script.goodnight", "state": "private state"},
            ]),
            report("2026-11-10T02:51:59Z", "unhealthy", [{"entity_id": "script.good_morning", "state": "unknown"}]),
            report("2026-11-11T02:52:00Z", "unhealthy"),
        ])
        self.assertEqual(code, 0)
        self.assertEqual(result["retained_reports"], 3)
        self.assertEqual(result["last_report"], {"observed_at": "2026-11-10T16:59:00+00:00", "status": "healthy"})
        self.assertEqual(result["omitted_unrecognized_failures"], 2)
        self.assertEqual(result["nonhealthy_critical_reports"], [
            {"observed_at": "2026-11-10T02:51:59+00:00", "status": "unhealthy", "failures": [{"entity_id": "script.good_morning", "state": "unknown"}]},
            {"observed_at": "2026-11-10T06:21:00+00:00", "status": "unhealthy", "failures": [{"entity_id": "climate.master_suite", "state": "unavailable"}]},
        ])

    def test_empty_or_unreadable_history_is_not_reported_as_healthy(self):
        self.assertEqual(self.invoke()[0], 2)
        code, result = self.invoke(error=subprocess.CalledProcessError(1, ["journalctl"], stderr="private error"))
        self.assertEqual((code, result), (2, {"status": "unknown", "error_type": "CalledProcessError"}))


class ClimateEntityDiagnosticsTests(unittest.TestCase):
    def invoke(self, lines=(), error=None, denied=False, args=(), state_error=None, state=None):
        socket = MagicMock()
        socket.__enter__.return_value = socket

        def receive_command(raw):
            message = json.loads(raw)
            if message["type"] not in ("auth", "config/entity_registry/get", "config_entries/get"):
                raise PermissionError("Fixture rejects non-read commands")
            if message["type"] == "config/entity_registry/get" and message.get("entity_id") != "climate.master_suite":
                raise PermissionError("Fixture rejects unrelated entities")

        socket.send.side_effect = receive_command
        socket.recv.side_effect = list(map(json.dumps, [
            {"type": "auth_required"}, {"type": "auth_ok"},
            {"id": 1, "type": "result", "success": not denied, "result": {
                "entity_id": "climate.master_suite", "platform": "homekit_controller",
                "config_entry_id": "a" * 32, "disabled_by": None,
                "unique_id": "private-device", "name": "private-title",
            }, "error": {"message": "private-error"}},
            {"id": 2, "type": "result", "success": True, "result": [
                {"entry_id": "b" * 32, "domain": "ecobee", "state": "setup_error"},
                {"entry_id": "a" * 32, "domain": "homekit_controller", "state": "loaded", "title": "private-title", "data": {"password": "private-password"}},
            ]},
        ]))
        client = MagicMock()
        client.connect.return_value = socket
        modules = {name: MagicMock() for name in ("websockets", "websockets.sync")}
        modules["websockets.sync.client"] = client
        journal = subprocess.CompletedProcess([], 0, "\n".join(map(json.dumps, lines)))
        state = state if state is not None else {
            "entity_id": "climate.master_suite", "state": "heat",
            "last_changed": "2026-11-01T07:02:00Z", "last_updated": "2026-11-01T07:03:00Z",
            "attributes": {"private": "192.0.2.42"}, "context": {"user_id": "private"},
        }

        def state_response(request, **_kwargs):
            if request.full_url != "http://127.0.0.1:8123/api/states/climate.master_suite" or request.get_method() != "GET":
                raise PermissionError("Fixture rejects unrelated state or writes")
            if state_error:
                raise state_error
            response = MagicMock()
            response.__enter__.return_value = io.StringIO(json.dumps(state))
            return response

        output = io.StringIO()
        with patch.dict(sys.modules, modules), patch.object(Path, "read_text", return_value="private-token"), patch("subprocess.run", return_value=journal, side_effect=error), patch("urllib.request.urlopen", side_effect=state_response), patch.object(sys, "argv", ["reader", *args]), patch("sys.stdout", output):
            with self.assertRaises(SystemExit) as exit_status:
                runpy.run_path(str(ROOT / "modules/services/hass/climate-entity-diagnostics.py"), run_name="__main__")
        self.assertNotIn("private", output.getvalue())
        self.assertNotIn("192.0.2.42", output.getvalue())
        return exit_status.exception.code, json.loads(output.getvalue())

    def record(self, at, message):
        return {"__REALTIME_TIMESTAMP": str(round(datetime.fromisoformat(at).timestamp() * 1_000_000)), "MESSAGE": message}

    def test_runtime_mapping_and_bounded_error_categories_are_private(self):
        def record(at, message):
            if isinstance(message, str):
                level, body = message.split(" ", 1)
                logger = "" if body.startswith("[") else "[homeassistant.core] "
                message = f"2026-11-10 {at[:8]} {level} (MainThread) {logger}{body}"
                if at == "06:15:00":
                    message = "\x1b[33m" + message + "\x1b[0m"
                if at in {"06:15:00", "15:41:00"}:
                    message = list(message.encode("utf-8"))
            return self.record(f"2026-11-10T{at}+00:00", message)

        code, result = self.invoke([
            record("06:14:59.999999", "ERROR climate.master_suite timed out"),
            record("06:15:00", "WARNING [homeassistant.components.homekit_controller.connection] timed out private café 192.0.2.42"),
            record("06:38:00", "ERROR climate.master_suite connection reset private"),
            record("06:38:00.000001", "ERROR climate.master_suite timed out"),
            record("07:00:00", "ERROR climate.master_suite timed out"),
            record("08:49:00", "WARNING " + "a" * 32 + " Unauthorized 401 private"),
            record("08:50:00", "ERROR [homeassistant.components.homekit_controller_extra] timed out"),
            record("08:51:00", "ERROR climate.master_suite_backup timed out"),
            record("09:44:00", "ERROR [homeassistant.components.homekit_controller] 429 too many requests"),
            record("13:48:00", "ERROR [homeassistant.components.homekit_controller] private error"),
            record("15:40:00", "WARNING climate.master_suite unavailable and timed out"),
            record("15:41:00", "INFO [homeassistant.components.homekit_controller] Last ERROR for climate.master_suite: timeout; connection recovered"),
            record("15:42:00", [255]),
            record("15:43:00", [True, 2]),
            record("15:44:00", ["private", "messages"]),
        ])
        self.assertEqual(code, 0)
        self.assertEqual(result["mapping"], {
            "entity_id": "climate.master_suite", "platform": "homekit_controller",
            "config_entry_id": "a" * 32, "integration_domain": "homekit_controller",
            "integration_state": "loaded", "entity_disabled": False, "integration_disabled": False,
        })
        journal = result["journal"]
        self.assertEqual((journal["retained_records_in_windows"], journal["matched_records"], journal["nontext_messages_not_classified"]), (12, 6, 3))
        self.assertEqual(journal["decoded_byte_messages"], 2)
        self.assertEqual((journal["first_match"], journal["last_match"]), ("2026-11-10T06:15:00+00:00", "2026-11-10T15:40:00+00:00"))
        self.assertEqual({(row["scope"], row["category"]): row["count"] for row in journal["category_counts"]}, {
            ("entity_or_config_entry", "authentication"): 1,
            ("entity_or_config_entry", "connection_failure"): 1,
            ("entity_or_config_entry", "timeout"): 1,
            ("entity_or_config_entry", "unavailable"): 1,
            ("integration_wide_not_entity_specific", "rate_limited"): 1,
            ("integration_wide_not_entity_specific", "timeout"): 1,
            ("integration_wide_not_entity_specific", "unclassified_warning_or_error"): 1,
        })

    def test_incomplete_reads_preserve_mapping_without_exposing_errors(self):
        code, result = self.invoke()
        self.assertEqual(code, 2)
        self.assertEqual(result["mapping"]["platform"], "homekit_controller")
        self.assertEqual(result["journal"]["matched_records"], 0)
        self.assertIsNone(result["journal"]["first_match"])
        code, result = self.invoke(error=subprocess.CalledProcessError(1, ["journalctl"], stderr="private error"))
        self.assertEqual(code, 2)
        self.assertEqual(result["mapping"]["platform"], "homekit_controller")
        self.assertEqual(result["journal"], {"status": "unknown", "error_type": "CalledProcessError"})
        self.assertEqual(self.invoke(denied=True), (2, {"status": "unknown", "error_type": "ValueError"}))

    def test_recurrence_scopes_tracebacks_checker_timing_and_snapshot_are_private(self):
        args = ["--incident-start", "2026-11-01T06:59:00Z", "--incident-cutoff", "2026-11-01T07:12:00Z",
                "--recovered-at", "2026-11-01T07:05:00Z"]

        def warning(at, logger, body, level="WARNING"):
            local = datetime.fromisoformat(at.replace("Z", "+00:00")).astimezone(ZoneInfo("America/Chicago"))
            return self.record(at, f"{local:%Y-%m-%d %H:%M:%S} {level} (MainThread) [{logger}] {body}")

        byte_warning = warning("2026-11-01T07:00:00Z", "aiohomekit.controller.ip.connection",
                               "private café 192.0.2.42\nTraceback (most recent call last):\nTimeoutError")
        byte_warning["MESSAGE"] = list(byte_warning["MESSAGE"].encode())
        checker = self.record("2026-11-01T07:01:01Z", json.dumps({
            "schema_version": 1, "observed_at": "2026-11-01T07:01:00Z",
            "checks": {"critical_entities": {"status": "unhealthy", "failures": [
                {"entity_id": "climate.master_suite", "state": "unavailable"},
                {"entity_id": "private", "state": "private"},
            ]}, "repairs": {"private": "private"}},
        })) | {"_SYSTEMD_UNIT": "hass-health.service"}
        code, result = self.invoke([
            warning("2026-11-01T06:53:59.999999Z", "aiohomekit", "timeout"),
            warning("2026-11-01T06:54:00Z", "homeassistant.core", "climate.master_suite unavailable private"),
            warning("2026-11-01T06:59:59Z", "homeassistant.components.homekit_controller", "connection reset private"),
            byte_warning, checker,
            warning("2026-11-01T07:02:00Z", "aiohomekit_extra", "timeout private"),
            warning("2026-11-01T07:03:00Z", "aiohomekit", "Last ERROR: timeout", "INFO"),
            warning("2026-11-01T07:04:00Z", "aiohomekit", "private failure"),
            self.record("2026-11-01T07:04:01Z", "Traceback (most recent call last):\nTimeoutError private"),
            warning("2026-11-01T07:10:00Z", "aiohomekit", "authentication failed"),
            warning("2026-11-01T07:10:00.000001Z", "aiohomekit", "timeout"),
        ], args=args)
        self.assertEqual(code, 0)
        incident = result["incident"]
        self.assertEqual((incident["window_start"], incident["window_end"]),
                         ("2026-11-01T06:54:00+00:00", "2026-11-01T07:10:00+00:00"))
        # Fall-back crosses the repeated Chicago 01:00 hour; wall-clock subtraction would be wrong.
        self.assertEqual((incident["america_chicago_start"], incident["america_chicago_end"]),
                         ("2026-11-01T01:54:00-05:00", "2026-11-01T01:10:00-06:00"))
        self.assertTrue(incident["full_recovery_margin_included"])
        self.assertFalse(incident["truncated_at_30_minutes"])
        self.assertEqual(result["current_state"]["state"], "heat")
        self.assertEqual(result["current_state"]["last_changed"], "2026-11-01T07:02:00+00:00")
        self.assertEqual(result["transport_metadata"]["association"], "unknown")
        self.assertFalse(result["transport_metadata"]["collected"])
        journal = result["journal"]
        self.assertEqual((journal["retained_records_in_windows"], journal["matched_records"], journal["decoded_byte_messages"]), (8, 5, 1))
        self.assertEqual([event["scope"] for event in journal["events"]], [
            "entity_or_config_entry", "integration_wide_not_entity_specific",
            "homekit_library_not_entity_specific", "homekit_library_not_entity_specific",
            "homekit_library_not_entity_specific",
        ])
        self.assertEqual(journal["events"][2]["exception_types"], ["TimeoutError"])
        self.assertEqual(journal["events"][3]["categories"], ["unclassified_warning_or_error"])
        self.assertEqual(journal["checker_reports"], [{"observed_at": "2026-11-01T07:01:00+00:00",
                         "critical_entities_status": "unhealthy", "entity_failures": ["unavailable"]}])
        self.assertEqual(journal["retention_by_window"][0]["first_retained_ha_record"], "2026-11-01T06:54:00+00:00")
        self.assertEqual(journal["retention_by_window"][0]["last_retained_ha_record"], "2026-11-01T07:10:00+00:00")

    def test_recurrence_caps_window_and_does_not_export_unbounded_events(self):
        args = ["--incident-start", "2026-11-01T06:59:00.123456Z", "--incident-cutoff", "2026-11-01T08:00:00Z"]
        records = [self.record("2026-11-01T06:59:00.123456Z", "2026-11-01 06:59:00 ERROR (MainThread) [aiohomekit] timeout private") for _ in range(101)]
        records += [self.record("2026-11-01T07:24:00.123456Z", "retained INFO private"),
                    self.record("2026-11-01T07:24:00.123457Z", "out of bounds private")]
        code, result = self.invoke(records, args=args)
        self.assertEqual(code, 0)
        self.assertEqual(result["incident"]["window_start"], "2026-11-01T06:54:00.123456+00:00")
        self.assertEqual(result["incident"]["window_end"], "2026-11-01T07:24:00.123456+00:00")
        self.assertTrue(result["incident"]["truncated_at_30_minutes"])
        self.assertEqual(result["incident"]["recovery_status"], "unrecovered_at_cutoff_as_reported")
        journal = result["journal"]
        self.assertEqual((journal["retained_records_in_windows"], journal["matched_records"], len(journal["events"]), journal["matching_events_not_exported"]), (102, 101, 100, 1))
        self.assertEqual(journal["category_counts"], [{"scope": "homekit_library_not_entity_specific", "category": "timeout", "count": 101}])

    def test_recurrence_invalid_bounds_and_partial_reads_do_not_claim_health(self):
        valid = ["--incident-start", "2026-11-01T06:59:00Z", "--incident-cutoff", "2026-11-01T07:02:00Z"]
        for args in (
            valid[:2], [*valid, "--recovered-at", "2026-11-01T07:03:00Z"],
            [*valid[:3], "2026-11-01T06:58:00Z"],
            ["--incident-start", "2026-11-01T06:59:00-06:00", *valid[2:]],
            ["--incident-start", "2026-11-01T06:59:00", *valid[2:]],
            [*valid[:3], "2099-11-01T07:02:00Z"],
        ):
            with self.subTest(args=args):
                self.assertEqual(self.invoke(args=args), (2, {"status": "unknown", "error_type": "ValueError"}))
        code, result = self.invoke(args=[*valid, "--recovered-at", "2026-11-01T07:01:00Z"])
        self.assertEqual(code, 2)
        self.assertFalse(result["incident"]["full_recovery_margin_included"])
        self.assertEqual(result["journal"]["retention_by_window"][0]["retained_ha_records"], 0)
        code, result = self.invoke([self.record("2026-11-01T07:00:00Z", "retained private")],
                                   args=valid, state_error=OSError("private 192.0.2.42"))
        self.assertEqual(code, 2)
        self.assertEqual(result["current_state"], {"status": "unknown", "error_type": "OSError"})
        self.assertEqual(result["mapping"]["integration_domain"], "homekit_controller")
        self.assertEqual(result["journal"]["retained_records_in_windows"], 1)


class HaMonitorTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.key = Path(temp.name) / "key"
        self.key.write_text("private-ha-token")
        self.ready = Path(temp.name) / "state" / "nuc-ha-runtime-gatus.ready"
        self.ready.parent.mkdir()
        self.ready.touch()
        self.now = datetime.now(UTC)
        self.status = Path(temp.name) / "status.json"
        self.samples = [
            {"schema_version": 1, "kind": "ha_monitor_sample", "observed_at": (self.now - timedelta(seconds=seconds + 1)).isoformat(), "success": True, "service_result": "success"}
            for seconds in (0, 120)
        ]
        self.status.write_text(json.dumps(self.samples[0]))
        self.probes = [
            {"success": True, "timestamp": (self.now - timedelta(seconds=seconds)).isoformat(), "hostname": "private-address", "errors": ["private-error"]}
            for seconds in (0, 120)
        ]
        self.reports = [
            {"schema_version": 1, "observed_at": (self.now - timedelta(seconds=seconds + 2)).isoformat(),
             "status": "healthy", "checks": {"repairs": {"status": "healthy", "issues": ["private-HA-report"]}}}
            for seconds in (120, 0)
        ]
        self.timer_active = True
        self.server_active = True
        self.api_failure = False
        self.served_status = "healthy"

    def api(self, url, **_kwargs):
        self.assertIsInstance(url, str)  # No Request carrying a POST or credentials.
        if url == "http://127.0.0.1:8124/health":
            body = json.dumps({"status": self.served_status, "extra": "private-response"})
            if self.served_status != "healthy":
                raise HTTPError(url, 503, "private-reason", {}, io.BytesIO(body.encode()))
            response = io.StringIO(body)
            response.status = 200
            return response
        self.assertTrue(url.startswith("http://127.0.0.1:8084/"))
        if self.api_failure:
            raise HTTPError(url, 503, "private-reason", {}, io.BytesIO(b"private-response"))
        response = io.StringIO(json.dumps({"results": self.probes, "events": [{"timestamp": self.now.isoformat(), "type": "HEALTHY", "extra": "private"}]}))
        response.status = 200
        return response

    def command(self, args, **_kwargs):
        if args[0] == "journalctl":
            return subprocess.CompletedProcess(args, 0, "\n".join(map(json.dumps, self.reports + self.samples)))
        active = self.timer_active if args[-1] == "hass-health.timer" else self.server_active
        return subprocess.CompletedProcess(args, 0 if active else 3)

    def invoke(self, action, *extra):
        output = io.StringIO()
        with patch("urllib.request.urlopen", side_effect=self.api), patch("subprocess.run", side_effect=self.command), patch("sys.stdout", output), patch("sys.argv", ["monitor-gatus.py", action, "--token-file", str(self.key), "--ready-file", str(self.ready), "--status-file", str(self.status), *extra]):
            with self.assertRaises(SystemExit) as exit_status:
                runpy.run_path(str(ROOT / "modules/services/hass/monitor-gatus.py"), run_name="__main__")
        self.assertNotIn("private", output.getvalue())
        return exit_status.exception.code, json.loads(output.getvalue())

    def test_setup_arms_only_after_local_backend_and_credential_validation(self):
        self.ready.unlink()
        self.api_failure = True
        self.assertEqual(self.invoke("setup")[0], 2)
        self.assertFalse(self.ready.exists())
        self.api_failure = False
        code, report = self.invoke("setup")
        self.assertEqual(code, 0)
        self.assertTrue(self.ready.is_file())
        self.assertTrue(report["provisioned"])
        self.assertEqual(self.invoke("setup")[0], 0)

    def test_missing_credential_cannot_arm_monitor(self):
        self.ready.unlink()
        self.key.unlink()
        self.assertEqual(self.invoke("setup")[0], 2)
        self.assertFalse(self.ready.exists())

    def test_live_verification_requires_recent_reports_pings_and_active_timer(self):
        code, report = self.invoke("status", "--require-live")
        self.assertEqual(code, 0)
        self.assertEqual(report["probe_report_correlation"], {"success_healthy": 2})
        self.assertEqual(report["journal"]["statuses"], {"healthy": 2})
        self.timer_active = False
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.timer_active = True
        self.server_active = False
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.server_active = True
        self.probes[0]["timestamp"] = (self.now - timedelta(minutes=6)).isoformat()
        self.probes[1]["timestamp"] = (self.now - timedelta(minutes=7)).isoformat()
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)

    def test_backend_errors_are_sanitized(self):
        self.api_failure = True
        code, report = self.invoke("status")
        self.assertEqual(code, 2)
        self.assertEqual(report["error_type"], "HTTPError")
        self.assertEqual(report["http_status"], 503)

    def test_diagnostics_distinguish_healthy_sample_from_unreadable_http_sample(self):
        self.served_status = "unknown"
        self.probes[0]["success"] = False
        code, report = self.invoke("status")
        self.assertEqual(code, 0)
        self.assertEqual(report["local_status"]["status"], "healthy")
        self.assertEqual(report["local_http"], {"http_status": 503, "status": "unknown"})
        self.assertEqual(report["probe_report_correlation"]["failure_healthy"], 1)
        self.probes[0]["success"] = True
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)
        self.served_status = "private-unexpected-status"
        self.assertEqual(self.invoke("status")[1]["local_http"]["status"], "invalid")

    def test_read_only_status_cannot_arm_an_unprovisioned_timer(self):
        self.ready.unlink()
        code, report = self.invoke("status", "--require-live")
        self.assertEqual(code, 1)
        self.assertFalse(report["provisioned"])
        self.assertFalse(self.ready.exists())
        self.assertEqual(self.invoke("setup")[0], 0)
        self.assertEqual(self.invoke("status", "--require-live")[0], 0)
        # Several Gatus probes of a single completion are not two timer runs.
        self.samples = self.samples[:1]
        self.assertEqual(self.invoke("status", "--require-live")[0], 1)

    def test_signal_correlation_distinguishes_false_alarms_and_coverage_gaps(self):
        self.probes[0]["success"] = False
        self.probes[1]["timestamp"] = (self.now - timedelta(minutes=10)).isoformat()
        code, report = self.invoke("status")
        self.assertEqual(code, 0)
        self.assertEqual(report["probe_report_correlation"], {"failure_healthy": 1, "success_stale_or_missing_sample": 1})
        self.reports[-1]["status"] = "unhealthy"
        self.reports[-1]["checks"]["integrations"] = {"status": "unhealthy"}
        self.samples[0]["success"] = False
        self.samples[0]["service_result"] = "exit-code"
        _, report = self.invoke("status")
        self.assertEqual(report["probe_report_correlation"]["failure_unhealthy"], 1)
        self.assertEqual(report["journal"]["failing_checks"], {"integrations": 1})
        self.assertEqual(report["failed_samples_not_observed"], 0)
        self.samples[0]["service_result"] = "timeout"
        self.assertEqual(self.invoke("status")[1]["probe_report_correlation"]["failure_timeout"], 1)
        self.probes = self.probes[1:]
        self.assertEqual(self.invoke("status")[1]["failed_samples_not_observed"], 1)

    def test_publish_covers_success_exit_code_timeout_and_signal(self):
        for result in ("success", "exit-code", "timeout", "signal"):
            with self.subTest(result=result), patch.dict(os.environ, {"SERVICE_RESULT": result}):
                code, report = self.invoke("publish")
                self.assertEqual(code, 0)
                self.assertEqual(report["success"], result == "success")
                self.assertEqual(json.loads(self.status.read_text()), report)
                self.assertEqual(self.status.stat().st_mode & 0o777, 0o644)

    def test_http_status_rejects_failed_missing_invalid_stale_and_future_samples(self):
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        process = subprocess.Popen(
            [sys.executable, str(ROOT / "modules/services/hass/monitor-gatus.py"), "serve", "--port", str(port), "--status-file", str(self.status)],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        try:
            url = f"http://127.0.0.1:{port}/health"
            deadline = time.monotonic() + 5
            while True:
                try:
                    with urlopen(url, timeout=1) as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(set(json.load(response)), {"status", "fresh", "sampled_at"})
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(0.01)
            for state in ("failure", "missing", "invalid", "stale", "future"):
                with self.subTest(state=state):
                    sample = self.samples[0].copy()
                    if state == "failure":
                        sample["success"] = False
                    if state in ("stale", "future"):
                        sample["observed_at"] = (datetime.now(UTC) + timedelta(seconds=-301 if state == "stale" else 60)).isoformat()
                    self.status.write_text(json.dumps(sample))
                    if state == "missing":
                        self.status.unlink()
                    if state == "invalid":
                        self.status.write_text("not JSON")
                    with self.assertRaises(HTTPError) as error:
                        urlopen(url, timeout=1)
                    self.assertEqual(error.exception.code, 503)
                    body = json.load(error.exception)
                    self.assertNotEqual(body["status"], "healthy")
                    error.exception.close()
            self.status.write_text(json.dumps(self.samples[0]))
            with urlopen(url, timeout=1) as response:
                self.assertEqual(response.status, 200)
        finally:
            process.terminate()
            process.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
