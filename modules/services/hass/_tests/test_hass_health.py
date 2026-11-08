"""Exercise the CLI over a local HA-protocol server, without physical devices."""

import json
import os
import subprocess
import sys
import threading
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from websockets.exceptions import WebSocketException
from websockets.sync.server import serve

CLI = (
    Path(sys.argv.pop(1))
    if len(sys.argv) > 1
    else Path(__file__).resolve().parents[1] / "hass-health.py"
)


class HassHealthTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime.now(UTC)
        self.responses = {
            "get_config": {"version": "2026.9.2"},
            "get_states": [{"entity_id": "climate.test", "state": "heat"}],
            "config_entries/get": [
                {
                    "entry_id": "enabled",
                    "domain": "test",
                    "state": "loaded",
                    "disabled_by": None,
                    "title": "private integration title",
                    "data": {"password": "private credential"},
                },
                {
                    "entry_id": "disabled",
                    "domain": "backup",
                    "state": "not_loaded",
                    "disabled_by": "user",
                },
            ],
            "repairs/list_issues": {"issues": [{"ignored": True, "severity": "error"}]},
            "trace/list": [
                self.trace("new", 1),
                self.trace("old-error", 48, error="private payload"),
            ],
        }
        self.denied = None
        self.denied_domain = None
        self.trace_responses = None
        self.invalid_auth = False
        self.disconnect = False
        self.received = []
        self.server_errors = []

        def handler(socket):
            try:
                socket.send(json.dumps({"type": "auth_required"}))
                auth = json.loads(socket.recv(timeout=3))
                self.assertEqual(
                    auth, {"type": "auth", "access_token": "fixture-token"}
                )
                socket.send(
                    json.dumps(
                        {"type": "auth_invalid" if self.invalid_auth else "auth_ok"}
                    )
                )
                if self.invalid_auth or self.disconnect:
                    return
                for raw in socket:
                    message = json.loads(raw)
                    self.received.append(message)
                    command = message["type"]
                    self.assertIn(command, self.responses)
                    denied = command == self.denied and (
                        self.denied_domain is None
                        or message.get("domain") == self.denied_domain
                    )
                    response = {
                        "id": message["id"],
                        "type": "result",
                        "success": not denied,
                    }
                    if denied:
                        response["error"] = {
                            "code": "unauthorized",
                            "message": "private-error-secret",
                        }
                    elif command == "trace/list" and self.trace_responses is not None:
                        response["result"] = self.trace_responses[message["domain"]]
                    else:
                        response["result"] = self.responses[command]
                    socket.send(json.dumps(response))
            except (
                AssertionError,
                OSError,
                ValueError,
                KeyError,
                WebSocketException,
            ) as error:
                self.server_errors.append(error)

        self.server = serve(handler, "127.0.0.1", 0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.socket.getsockname()[1]}"

    def tearDown(self):
        self.server.shutdown()
        self.thread.join(timeout=3)
        self.assertFalse(self.thread.is_alive())
        self.assertEqual(self.server_errors, [])

    def trace(self, run_id, hours, **extra):
        return {
            "domain": "script",
            "item_id": "test",
            "run_id": run_id,
            "state": "stopped",
            "script_execution": "finished",
            "last_step": "sequence/0",
            "timestamp": {
                "start": (self.now - timedelta(hours=hours)).isoformat(),
                "finish": self.now.isoformat(),
            },
            **extra,
        }

    def invoke(self, *args, env=None):
        environment = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("HASS_")
        }
        environment.update({"HASS_TOKEN": "fixture-token"})
        environment.update(env or {})
        process = subprocess.run(
            [sys.executable, str(CLI), *args, "--url", self.url, "--json"],
            env=environment,
            text=True,
            capture_output=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(process.stderr, "")
        self.assertNotIn("fixture-token", process.stdout)
        self.assertNotIn("private", process.stdout)
        return process.returncode, json.loads(process.stdout)

    def health(self, *extra):
        return self.invoke(
            "health",
            "--expected-version",
            "2026.9.2",
            "--entity",
            "climate.test",
            *extra,
        )

    def test_healthy_ignores_disabled_integrations_dismissed_repairs_and_old_errors(
        self,
    ):
        code, report = self.health()
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "healthy")
        self.assertEqual(report["checks"]["recent_traces"]["failures"], [])
        self.assertEqual(
            report["not_checked"],
            ["restic_backup_freshness", "physical_device_outcomes"],
        )

    def test_ignored_integrations_are_excluded_but_enabled_unloaded_entries_fail(self):
        self.responses["config_entries/get"].append(
            {
                "entry_id": "ignored",
                "domain": "ecobee",
                "source": "ignore",
                "state": "not_loaded",
                "disabled_by": None,
            }
        )
        code, report = self.health()
        self.assertEqual(code, 0)
        self.assertEqual(report["checks"]["integrations"]["failures"], [])
        self.assertEqual(
            report["checks"]["integrations"]["entries"],
            [{"entry_id": "enabled", "domain": "test", "state": "loaded"}],
        )

        self.responses["config_entries/get"][0]["state"] = "not_loaded"
        code, report = self.health()
        self.assertEqual(code, 1)
        self.assertEqual(
            report["checks"]["integrations"]["failures"],
            [{"entry_id": "enabled", "domain": "test", "state": "not_loaded"}],
        )

    def test_bluetooth_retry_signatures_do_not_expose_error_parameters(self):
        for reason, expected in (
            (
                "Bluetooth adapter None with address AA:BB:CC:DD:EE:FF not found",
                ["adapter_not_found"],
            ),
            (
                "private adapter: Failed to start Bluetooth: "
                "[org.bluez.Error.NotReady] private exception parameter",
                ["bluez_not_ready"],
            ),
            ("private unrecognized error", []),
            (None, []),
        ):
            with self.subTest(reason=reason):
                self.responses["config_entries/get"][0].update(
                    domain="bluetooth", state="setup_retry", reason=reason
                )
                code, report = self.health()
                self.assertEqual(code, 1)
                self.assertEqual(
                    report["checks"]["integrations"]["failures"],
                    [
                        {
                            "entry_id": "enabled",
                            "domain": "bluetooth",
                            "state": "setup_retry",
                            "retry_reason_codes": expected,
                        }
                    ],
                )
                self.assertNotIn("AA:BB:CC:DD:EE:FF", json.dumps(report))

    def test_empty_trace_error_is_a_failure_in_health_and_trace_list(self):
        self.trace_responses = {
            "automation": [],
            "script": [self.trace("timeout", 0, error=""), self.trace("success", 1)],
        }
        code, report = self.health()
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "unhealthy")
        failures = report["checks"]["recent_traces"]["failures"]
        self.assertEqual([trace["run_id"] for trace in failures], ["timeout"])
        self.assertTrue(failures[0]["has_error"])

        code, report = self.invoke("traces", "list", "--domain", "script")
        self.assertEqual(code, 0)
        self.assertEqual(
            [(trace["run_id"], trace["has_error"]) for trace in report["result"]["traces"]],
            [("timeout", True), ("success", False)],
        )

    def test_partial_trace_reads_preserve_failures_and_report_incomplete_domains(self):
        self.denied = "trace/list"
        for denied_domain, readable_domain in (
            ("automation", "script"),
            ("script", "automation"),
        ):
            for failed in (True, False):
                with self.subTest(denied_domain=denied_domain, failed=failed):
                    self.denied_domain = denied_domain
                    self.trace_responses = {
                        readable_domain: [
                            self.trace(
                                "readable", 0, domain=readable_domain,
                                **({"error": "private failure"} if failed else {}),
                            )
                        ]
                    }
                    code, report = self.health()
                    self.assertEqual(code, 1 if failed else 2)
                    expected_status = "unhealthy" if failed else "unknown"
                    self.assertEqual(report["status"], expected_status)
                    traces = report["checks"]["recent_traces"]
                    self.assertEqual(traces["status"], expected_status)
                    self.assertEqual(traces["incomplete_domains"], [denied_domain])
                    self.assertEqual(traces["retained_runs"], 1)
                    self.assertEqual(
                        [(trace["domain"], trace["run_id"]) for trace in traces["failures"]],
                        [(readable_domain, "readable")] if failed else [],
                    )

    def test_failures_and_unknown_checks_are_distinct(self):
        self.responses["config_entries/get"][0]["state"] = "setup_retry"
        self.responses["get_states"] = []
        self.responses["trace/list"] = [
            self.trace("failed", 0, error="private exception")
        ]
        self.denied = "repairs/list_issues"
        code, report = self.health("--expected-version", "2026.10.1")
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "unhealthy")
        checks = report["checks"]
        self.assertEqual(checks["repairs"]["status"], "unknown")
        self.assertEqual(checks["version"]["status"], "unhealthy")
        self.assertEqual(
            checks["critical_entities"]["failures"],
            [{"entity_id": "climate.test", "state": "missing"}],
        )
        self.assertEqual(
            checks["integrations"]["failures"],
            [{"entry_id": "enabled", "domain": "test", "state": "setup_retry"}],
        )
        self.assertTrue(checks["recent_traces"]["failures"][0]["has_error"])

    def test_incomplete_evidence_never_reports_healthy(self):
        for case in ("no_traces", "denied", "no_expectations", "not_triggered"):
            with self.subTest(case=case):
                self.responses["trace/list"] = (
                    [] if case == "no_traces" else [self.trace("new", 0)]
                )
                if case == "not_triggered":
                    self.responses["trace/list"] = [
                        self.trace("skipped", 0, not_triggered=True)
                    ]
                self.denied = "trace/list" if case == "denied" else None
                code, report = (
                    self.invoke("health")
                    if case == "no_expectations"
                    else self.health()
                )
                self.assertEqual(code, 2)
                self.assertEqual(report["status"], "unknown")

    def test_unavailable_entities_and_active_repairs_fail(self):
        for state in ("unknown", "unavailable"):
            with self.subTest(state=state):
                self.responses["get_states"][0]["state"] = state
                self.responses["repairs/list_issues"] = {
                    "issues": [
                        {
                            "domain": "test",
                            "issue_id": "reauth",
                            "severity": "error",
                            "ignored": False,
                        }
                    ]
                }
                code, report = self.health()
                self.assertEqual(code, 1)
                self.assertEqual(
                    report["checks"]["critical_entities"]["failures"][0]["state"], state
                )
                self.assertEqual(
                    report["checks"]["repairs"]["issues"][0]["issue_id"], "reauth"
                )

    def test_trace_list_sorts_limits_and_filters_output(self):
        self.responses["trace/list"] = [
            self.trace("old", 3),
            self.trace("new", 0, error="private service data"),
        ]
        code, report = self.invoke(
            "traces", "list", "--domain", "script", "--item-id", "test", "--limit", "1"
        )
        self.assertEqual(code, 0)
        self.assertEqual(report["result"]["total"], 2)
        self.assertEqual(
            [trace["run_id"] for trace in report["result"]["traces"]], ["new"]
        )
        self.assertEqual(self.received[0]["item_id"], "test")

    def test_trace_get_exposes_paths_conditions_and_context_but_no_payloads(self):
        self.responses["trace/get"] = self.trace(
            "failed",
            0,
            error="private top-level error",
            config={"private": "secret"},
            context={"id": "child", "parent_id": "parent", "user_id": "private-user"},
            trace={
                "sequence/0": [
                    {
                        "timestamp": self.now.isoformat(),
                        "error": "private error",
                        "changed_variables": {"private": "secret"},
                        "result": {"result": False, "params": "private"},
                    }
                ]
            },
        )
        code, report = self.invoke(
            "traces",
            "get",
            "--domain",
            "script",
            "--item-id",
            "test",
            "--run-id",
            "failed",
        )
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "ok")
        detail = report["result"]
        self.assertEqual(detail["context"], {"id": "child", "parent_id": "parent"})
        self.assertEqual(detail["steps"][0]["path"], "sequence/0")
        self.assertTrue(detail["steps"][0]["has_error"])
        self.assertIs(detail["steps"][0]["condition_result"], False)

        self.responses["trace/get"]["error"] = ""
        self.responses["trace/get"]["trace"]["sequence/0"][0]["error"] = ""
        self.responses["trace/get"]["trace"]["sequence/1"] = [{}]
        code, report = self.invoke(
            "traces", "get", "--domain", "script", "--item-id", "test",
            "--run-id", "failed",
        )
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "ok")
        self.assertTrue(report["result"]["has_error"])
        self.assertEqual(
            {step["path"]: step["has_error"] for step in report["result"]["steps"]},
            {"sequence/0": True, "sequence/1": False},
        )

    def test_authentication_failure_and_missing_token_are_json_errors(self):
        self.invalid_auth = True
        code, report = self.health()
        self.assertEqual(code, 2)
        self.assertIn("rejected the token", report["error"])
        code, report = self.invoke("health", env={"HASS_TOKEN": ""})
        self.assertEqual(code, 2)
        self.assertIn("Set HASS_TOKEN", report["error"])
        self.assertEqual(self.received, [])

    def test_disconnection_is_unknown_not_an_empty_healthy_report(self):
        self.disconnect = True
        code, report = self.health()
        self.assertEqual(code, 2)
        self.assertEqual(report["status"], "unknown")
        self.assertTrue(
            all(value["status"] == "unknown" for value in report["checks"].values())
        )
        self.assertEqual(len(report["checks"]), 5)


if __name__ == "__main__":
    unittest.main()
