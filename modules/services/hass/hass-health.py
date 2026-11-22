#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["websockets>=15,<17"]
# ///
"""Home Assistant health, private-data-filtered traces and explicit HomeKit retry."""

import argparse
import json
import math
import os
import sys
import time
from urllib.request import Request, urlopen
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

from websockets.exceptions import WebSocketException
from websockets.sync.client import connect


class InspectionError(Exception):
    """A failed inspection, not evidence that the inspected feature is healthy."""


class HomeAssistant:
    def __init__(self, socket, timeout):
        self.socket = socket
        self.timeout = timeout
        self.request_id = 0

    def receive(self):
        return json.loads(self.socket.recv(timeout=self.timeout))

    def request(self, command, **fields):
        self.request_id += 1
        self.socket.send(json.dumps({"id": self.request_id, "type": command, **fields}))
        response = self.receive()
        if response.get("id") != self.request_id or response.get("type") != "result":
            raise InspectionError("Unexpected HA response; check the server version.")
        if not response.get("success"):
            code = response.get("error", {}).get("code")
            if code == "unauthorized":
                raise InspectionError(
                    "HA denied access; use an administrator token for traces."
                )
            if code == "not_found":
                raise InspectionError(
                    "Trace not found; list retained runs and use their IDs."
                )
            raise InspectionError(
                "HA rejected the read request; check API compatibility and permissions."
            )
        return response["result"]


def trace_summary(trace):
    result = {
        key: trace.get(key)
        for key in (
            "domain",
            "item_id",
            "run_id",
            "state",
            "script_execution",
            "last_step",
            "timestamp",
        )
    }
    result["has_error"] = "error" in trace
    result["not_triggered"] = trace.get("not_triggered", False)
    return result


def trace_detail(trace):
    result = trace_summary(trace)
    context = trace.get("context", {})
    result["context"] = {key: context.get(key) for key in ("id", "parent_id")}
    result["steps"] = [
        {
            "path": path,
            "timestamp": step.get("timestamp"),
            "has_error": "error" in step,
            "condition_result": step.get("result", {}).get("result")
            if isinstance(step.get("result", {}).get("result"), bool)
            else None,
        }
        for path, steps in trace.get("trace", {}).items()
        for step in steps
    ]
    result["omitted"] = ["config", "variables", "payloads", "error_text", "user_id"]
    return result


def check(status, **details):
    return {"status": status, **details}


def health(ha, args, now):
    checks = {}

    def inspect(name, operation):
        try:
            checks[name] = operation()
        except (
            InspectionError,
            OSError,
            WebSocketException,
            ValueError,
            KeyError,
            TypeError,
        ):
            checks[name] = check(
                "unknown",
                reason="Read failed; check connectivity, API compatibility, and token permissions.",
            )

    def version():
        config = ha.request("get_config")
        expected = args.expected_version
        return check(
            "unknown"
            if not expected
            else "healthy"
            if config["version"] == expected
            else "unhealthy",
            running=config["version"],
            expected=expected,
        )

    def integrations():
        entries = []
        for entry in ha.request("config_entries/get"):
            if entry.get("disabled_by") or entry.get("source") == "ignore":
                continue
            summary = {key: entry[key] for key in ("entry_id", "domain", "state")}
            if entry["domain"] == "bluetooth" and entry["state"] == "setup_retry":
                # Match upstream failure signatures, never publish raw errors,
                # adapter addresses, titles, or exception parameters.
                reason = entry.get("reason") or ""
                summary["retry_reason_codes"] = [
                    code
                    for signature, code in (
                        ("Bluetooth adapter None with address ", "adapter_not_found"),
                        ("Timed out starting Bluetooth after", "scanner_start_timeout"),
                        ("DBus service not found;", "dbus_service_not_found"),
                        ("DBus connection broken:", "dbus_connection_broken"),
                        ("org.bluez.Error.NotReady", "bluez_not_ready"),
                        ("org.bluez.Error.InProgress", "bluez_in_progress"),
                        ("org.bluez.Error.Failed", "bluez_failed"),
                        ("Starting bluetooth scanner aborted", "scanner_start_aborted"),
                    )
                    if signature in reason
                ]
            if entry["state"] != "loaded" and entry["domain"] != "bluetooth":
                reason = (entry.get("reason") or "").lower()
                reason_codes = [
                    code for code, signatures in (
                        ("connection_refused", ("connection refused", "connectionrefusederror")),
                        ("connection_failed", ("cannot connect", "failed to connect", "cannotconnect", "connect call failed")),
                        ("timeout", ("timed out", "timeout")),
                        ("authentication", ("authentication", "unauthorized", "invalid auth")),
                        ("missing_dependency", ("no module named", "cannot import name", "importerror")),
                        ("dependency_failed", ("dependency", "dependencies")),
                        ("bluetooth_not_ready", ("org.bluez.error.notready", "dbus service not found")),
                    ) if any(signature in reason for signature in signatures)
                ]
                if reason_codes:
                    summary["failure_reason_codes"] = reason_codes
            entries.append(summary)
        failures = [entry for entry in entries if entry["state"] != "loaded"]
        return check(
            "unhealthy" if failures else "healthy", entries=entries, failures=failures
        )

    def repairs():
        issues = [
            {
                key: issue.get(key)
                for key in ("domain", "issue_id", "severity", "created")
            }
            for issue in ha.request("repairs/list_issues")["issues"]
            if not issue.get("ignored")
        ]
        failures = [
            issue
            for issue in issues
            if issue["severity"] != "warning"
            or f"{issue['domain']}/{issue['issue_id']}@{issue['created']}"
            not in args.expected_warning
        ]
        return check(
            "unhealthy" if failures else "healthy", issues=issues, failures=failures
        )

    def entities():
        states = {state["entity_id"]: state for state in ha.request("get_states")}
        if args.climate_capture_request:
            # A separate path-triggered unit does diagnostics. Never delay or
            # change the health result because a capture cannot be queued.
            entity = states.get("climate.master_suite")
            observed = entity.get("state") if entity else "missing"
            sample = {
                "observed_at": now.isoformat(),
                "state": observed if observed in {"unavailable", "unknown", "missing"} else "available",
            }
            try:
                path = Path(args.climate_capture_request)
                temporary = path.with_suffix(".tmp")
                temporary.write_text(json.dumps(sample))
                temporary.chmod(0o644)
                temporary.replace(path)
            except OSError:
                print("Climate diagnostic request could not be queued.", file=sys.stderr)
        failures = []
        for entity_id in args.entity:
            state = states.get(entity_id)
            if state is None or state["state"] in ("unknown", "unavailable"):
                failures.append(
                    {
                        "entity_id": entity_id,
                        "state": state["state"] if state else "missing",
                    }
                )
        return check(
            "unknown" if not args.entity else "unhealthy" if failures else "healthy",
            checked=len(args.entity),
            failures=failures,
        )

    def traces():
        cutoff = now - timedelta(hours=args.since_hours)
        recent = []
        incomplete_domains = []
        for domain in ("automation", "script"):
            try:
                for trace in ha.request("trace/list", domain=domain):
                    if (
                        not trace.get("not_triggered")
                        and datetime.fromisoformat(trace["timestamp"]["start"]) >= cutoff
                    ):
                        recent.append(trace)
            except (
                InspectionError,
                OSError,
                WebSocketException,
                ValueError,
                KeyError,
                TypeError,
            ):
                incomplete_domains.append(domain)
        failures = [trace_summary(trace) for trace in recent if "error" in trace]
        failures.sort(key=lambda trace: trace["timestamp"]["start"], reverse=True)
        return check(
            "unhealthy"
            if failures
            else "unknown"
            if incomplete_domains or not recent
            else "healthy",
            since=cutoff.isoformat(),
            retained_runs=len(recent),
            failures=failures,
            incomplete_domains=incomplete_domains,
            coverage="Retained traces only; evicted or never-recorded runs cannot be inspected.",
        )

    for name, operation in (
        ("version", version),
        ("integrations", integrations),
        ("repairs", repairs),
        ("critical_entities", entities),
        ("recent_traces", traces),
    ):
        inspect(name, operation)
    statuses = {value["status"] for value in checks.values()}
    status = (
        "unhealthy"
        if "unhealthy" in statuses
        else "unknown"
        if "unknown" in statuses
        else "healthy"
    )
    return {
        "schema_version": 1,
        "observed_at": now.isoformat(),
        "status": status,
        "checks": checks,
        "not_checked": ["restic_backup_freshness", "physical_device_outcomes"],
    }


def homekit_entry(ha, args, token, now):
    """Identify one HomeKit device; reload only on explicit opt-in and failed state."""
    def entry():
        matches = [item for item in ha.request("config_entries/get")
                   if item["entry_id"] == args.entry_id]
        if len(matches) != 1 or matches[0]["domain"] != "homekit_controller":
            raise InspectionError("The requested entry is not a known HomeKit Controller entry.")
        return matches[0]

    if not args.entry_id.isascii() or not args.entry_id.isalnum() or len(args.entry_id) > 64:
        raise InspectionError("Use the exact alphanumeric config-entry ID.")
    before = entry()
    devices = [device for device in ha.request("config/device_registry/list")
               if args.entry_id in device.get("config_entries", [])]
    entities = [item for item in ha.request("config/entity_registry/list")
                if item.get("config_entry_id") == args.entry_id]
    states = {item["entity_id"]: item["state"] for item in ha.request("get_states")}
    result = {
        "schema_version": 1, "observed_at": now.isoformat(),
        "entry_id": args.entry_id, "domain": "homekit_controller",
        "state_before": before["state"],
        "devices": [{key: device.get(key) for key in ("manufacturer", "model")}
                    for device in devices],
        "entities": [{"entity_id": item["entity_id"],
                      "state": states.get(item["entity_id"], "missing")}
                     for item in entities],
        "reload_requested": args.reload,
        "omitted": ["titles", "names", "addresses", "identifiers", "pairing_data", "raw_errors"],
    }
    if args.reload:
        if before.get("disabled_by") or before.get("source") == "ignore" or before["state"] not in {"setup_retry", "setup_error"}:
            raise InspectionError("Reload refused: the enabled HomeKit entry must be in setup_retry or setup_error.")
        request = Request(
            args.url.rstrip("/") + "/api/config/config_entries/entry/" + args.entry_id + "/reload",
            data=b"", headers={"Authorization": "Bearer " + token}, method="POST",
        )
        # Exactly one POST. A lost response is indeterminate, never replayed.
        try:
            with urlopen(request, timeout=args.timeout) as response:
                reply = json.load(response)
            if not isinstance(reply, dict) or type(reply.get("require_restart")) is not bool:
                raise ValueError("Unexpected reload response")
            result["reload_result"] = "restart_required" if reply["require_restart"] else "accepted"
        except (OSError, ValueError, AttributeError) as error:
            result["reload_result"] = "indeterminate"
            result["reload_error_type"] = type(error).__name__
        for attempt in range(7):
            after = entry()
            if after["state"] == "loaded" or attempt == 6:
                break
            time.sleep(5)
    else:
        after = before
    result["state_after"] = after["state"]
    result["status"] = "healthy" if after["state"] == "loaded" else "unhealthy"
    result["completed_at"] = datetime.now(UTC).isoformat()
    return result


def positive_number(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("must be a finite number greater than zero")
    return number


def parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", help="Emit JSON only on stdout.")
    common.add_argument(
        "--url",
        default=os.getenv(
            "HASS_SERVER", os.getenv("HASS_URL", "http://127.0.0.1:8123")
        ),
    )
    common.add_argument(
        "--token-file",
        default=os.getenv("HASS_TOKEN_FILE"),
        help="Token file; otherwise use HASS_TOKEN.",
    )
    common.add_argument(
        "--timeout",
        type=positive_number,
        default=10,
        help="Seconds per network operation.",
    )
    root = argparse.ArgumentParser(
        prog="hass-health",
        description=__doc__,
        epilog="Exit codes: 0 healthy/success, 1 unhealthy, 2 unknown/error. Only homekit-entry --reload writes to HA.",
    )
    commands = root.add_subparsers(dest="command", required=True)
    status = commands.add_parser(
        "health",
        parents=[common],
        help="Inspect versions, integrations, Repairs, entities, and retained failures.",
    )
    status.add_argument(
        "--expected-version", default=os.getenv("HASS_EXPECTED_VERSION")
    )
    status.add_argument(
        "--entity",
        action="append",
        help="Critical entity ID; repeat to supply an explicit list.",
    )
    status.add_argument(
        "--expected-warning",
        action="append",
        default=[],
        metavar="DOMAIN/ISSUE_ID@CREATED",
        help="Report this exact dated Repair warning without failing; repeat as needed. Errors always fail.",
    )
    status.add_argument("--since-hours", type=positive_number, default=24)
    status.add_argument(
        "--climate-capture-request",
        help="Atomically queue only the fixed climate entity's availability for a separate system unit.",
    )
    traces = commands.add_parser(
        "traces",
        help="Read retained traces without variables, payloads, or error text.",
    )
    actions = traces.add_subparsers(dest="trace_action", required=True)
    listing = actions.add_parser("list", parents=[common])
    detail = actions.add_parser("get", parents=[common])
    for command in (listing, detail):
        command.add_argument(
            "--domain", choices=("automation", "script"), required=True
        )
        command.add_argument(
            "--item-id",
            required=command is detail,
            help="Automation config ID, or script key without 'script.'.",
        )
    listing.add_argument(
        "--limit", type=int, choices=range(1, 101), default=20, metavar="1..100"
    )
    detail.add_argument("--run-id", required=True)
    homekit = commands.add_parser("homekit-entry", parents=[common],
                                  help="Identify one HomeKit entry; optionally retry it with explicit approval.")
    homekit.add_argument("--entry-id", required=True)
    homekit.add_argument("--reload", action="store_true", help="Reload this failed HomeKit entry once, never HA itself.")
    return root


def run(args):
    token = (
        Path(args.token_file).read_text().strip()
        if args.token_file
        else os.getenv("HASS_TOKEN", "").strip()
    )
    if not token:
        raise InspectionError(
            "Set HASS_TOKEN or pass --token-file with an existing HA token file."
        )
    url = urlsplit(args.url)
    if (
        url.scheme not in ("http", "https")
        or not url.hostname
        or url.username
        or url.password
        or url.query
        or url.fragment
    ):
        raise InspectionError(
            "Use an http(s) HA base URL without credentials, query, or fragment."
        )
    if url.scheme == "http" and url.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise InspectionError(
            "Use HTTPS for remote HA connections; HTTP is allowed only on loopback."
        )
    endpoint = urlunsplit(
        (
            "wss" if url.scheme == "https" else "ws",
            url.netloc,
            url.path.rstrip("/") + "/api/websocket",
            "",
            "",
        )
    )
    with connect(
        endpoint,
        open_timeout=args.timeout,
        close_timeout=1,
        max_size=16 * 1024 * 1024,
        proxy=None,
    ) as socket:
        ha = HomeAssistant(socket, args.timeout)
        if ha.receive().get("type") != "auth_required":
            raise InspectionError("HA did not request authentication; check --url.")
        socket.send(json.dumps({"type": "auth", "access_token": token}))
        if ha.receive().get("type") != "auth_ok":
            raise InspectionError(
                "HA rejected the token; supply a valid token through HASS_TOKEN or --token-file."
            )
        now = datetime.now(UTC)
        if args.command == "homekit-entry":
            try:
                return homekit_entry(ha, args, token, now)
            except InspectionError as error:
                return {"schema_version": 1, "status": "unknown", "error": str(error)}
        if args.command == "health":
            if args.entity is None:
                args.entity = os.getenv("HASS_CRITICAL_ENTITIES", "").split()
            return health(ha, args, now)
        fields = {"domain": args.domain}
        if args.item_id:
            fields["item_id"] = args.item_id
        if args.trace_action == "get":
            fields["run_id"] = args.run_id
            result = trace_detail(ha.request("trace/get", **fields))
        else:
            traces = ha.request("trace/list", **fields)
            traces.sort(key=lambda trace: trace["timestamp"]["start"], reverse=True)
            result = {
                "total": len(traces),
                "traces": [trace_summary(trace) for trace in traces[: args.limit]],
            }
        return {
            "schema_version": 1,
            "observed_at": now.isoformat(),
            "status": "ok",
            "result": result,
        }


def main():
    args = parser().parse_args()
    try:
        result = run(args)
    except InspectionError as error:
        result = {"schema_version": 1, "status": "unknown", "error": str(error)}
    except (OSError, WebSocketException, ValueError, KeyError, TypeError):
        result = {
            "schema_version": 1,
            "status": "unknown",
            "error": "Inspection failed; check the token file, HA connectivity, and API compatibility.",
        }
    result.setdefault("observed_at", datetime.now(UTC).isoformat())
    if args.json:
        print(json.dumps(result, sort_keys=True))
    else:
        print(f"Home Assistant: {result['status']}")
        if "checks" in result:
            for name, value in result["checks"].items():
                print(f"  {name}: {json.dumps(value, sort_keys=True)}")
            print("  Not checked: " + ", ".join(result["not_checked"]))
        else:
            print(json.dumps(result.get("result", result.get("error")), indent=2))
    return {"ok": 0, "healthy": 0, "unhealthy": 1, "unknown": 2}[result["status"]]


if __name__ == "__main__":
    sys.exit(main())
