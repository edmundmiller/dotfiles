#!/usr/bin/env python3
"""Publish local HA monitor status and inspect Gatus without exporting HA contents."""

import argparse
from collections import Counter
from datetime import UTC, datetime, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import urlopen

READY = Path("/var/lib/hass-health/nuc-ha-runtime-gatus.ready")
STATUS = Path("/run/hass-health/status.json")
ENDPOINT = "/api/v1/endpoints/smart-home_home-assistant-runtime/statuses?pageSize=1500"
MAX_AGE = 300
CRITICAL_ENTITIES = {
    "climate.main_floor", "climate.master_suite", "script.goodnight",
    "script.good_morning", "script.get_ready_for_bed",
}


def timestamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def read_status(path):
    try:
        sample = json.loads(path.read_text())
        age = (datetime.now(UTC) - timestamp(sample["observed_at"])).total_seconds()
        fresh = 0 <= age <= MAX_AGE
        return {
            "status": ("healthy" if sample["success"] is True else "unhealthy") if fresh else "unknown",
            "fresh": fresh,
            "sampled_at": sample["observed_at"],
        }
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return {"status": "unknown", "fresh": False, "sampled_at": None}


def publish(args):
    result = os.environ["SERVICE_RESULT"]
    sample = {
        "schema_version": 1,
        "kind": "ha_monitor_sample",
        "observed_at": datetime.now(UTC).isoformat(),
        "success": result == "success",
        "service_result": result,
    }
    temporary = args.status_file.with_suffix(".tmp")
    temporary.write_text(json.dumps(sample))
    temporary.chmod(0o644)
    temporary.replace(args.status_file)
    return sample


def serve(args):
    class Handler(BaseHTTPRequestHandler):
        # Bound an unfinished local request so later Gatus probes can proceed.
        timeout = 5

        def do_GET(self):
            if self.path != "/health":
                self.send_error(404)
                return
            status = read_status(args.status_file)
            body = json.dumps(status).encode()
            self.send_response(200 if status["status"] == "healthy" else 503)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args):
            pass

    # No HA token, report contents, or tailnet/firewall listener in this process.
    with HTTPServer(("127.0.0.1", args.port), Handler) as server:
        server.serve_forever()


def fetch(url):
    with urlopen(url, timeout=10) as response:
        return json.load(response)


def incident_diagnostics():
    """Fixed loopback reads and categorized two-hour journals; no raw log export."""
    now = datetime.now(UTC)
    since = now - timedelta(hours=2)
    result = {"since": since.isoformat(), "until": now.isoformat(), "http": {}, "units": {}}
    for port in (8084, 8124, 8126):
        item = {"observed_at": datetime.now(UTC).isoformat()}
        try:
            try:
                response = urlopen(f"http://127.0.0.1:{port}/health", timeout=5)
            except HTTPError as error:
                response = error
            with response:
                item["http_status"] = response.status
                item["content_type"] = response.headers.get("Content-Type")
                body = json.load(response)
                # These fixed health routes contain no credentials. Still allowlist
                # values rather than exporting an unexpected proxy/error body.
                item["body"] = {
                    key: value for key, value in body.items()
                    if (key == "status" and value in {"UP", "DOWN", "healthy", "unhealthy", "unknown"})
                    or (key in {"pending", "delivery_errors", "oldest_pending_seconds", "queue_used"}
                        and type(value) in {int, float})
                }
        except (OSError, ValueError, TypeError, AttributeError) as error:
            item["error_type"] = type(error).__name__
        result["http"][str(port)] = item
    for unit in ("gatus.service", "gatus-email.service", "home-assistant.service", "hass-health-http.service"):
        properties = "ActiveState,SubState,MainPID,NRestarts,ActiveEnterTimestamp,ExecMainStartTimestamp,ExecMainStartTimestampMonotonic,ExecReload"
        command = subprocess.run(["systemctl", "show", unit, "--property=" + properties],
                                 check=True, capture_output=True, text=True, timeout=5)
        metadata = dict(line.split("=", 1) for line in command.stdout.splitlines() if "=" in line)
        reload_command = metadata.pop("ExecReload", "")
        metadata["reload_sends_sighup"] = bool(re.search(r"\bkill\s+-HUP\b", reload_command))
        pid = metadata.get("MainPID", "0")
        if pid.isdecimal() and int(pid) > 0:
            try:
                metadata["executable"] = str(Path(f"/proc/{pid}/exe").resolve(strict=True))
            except OSError:
                metadata["executable"] = "unavailable"
        result["units"][unit] = metadata
    listeners = subprocess.run(["ss", "-H", "-ltnp", "sport = :8084"],
                               check=True, capture_output=True, text=True, timeout=5)
    result["gatus_listener_processes"] = [
        {"name": name, "pid": int(pid)}
        for name, pid in re.findall(r'\("([A-Za-z0-9_-]+)",pid=(\d+),', listeners.stdout)
    ]
    records = subprocess.run(
        ["journalctl", "-u", "home-assistant.service", "-u", "gatus.service", "-u", "gatus-email.service",
         "-u", "nixos-upgrade.service", "-u", "systemd-oomd.service",
         "--since", since.isoformat(), "--until", now.isoformat(), "--all", "-o", "json", "--no-pager"],
        check=True, capture_output=True, text=True, timeout=20,
    )
    events, retained, nontext = [], Counter(), 0
    signatures = {
        "timeout": r"timed? out|timeout", "connection_refused": r"connection refused|connectionrefusederror",
        "connection_failed": r"connect call failed|cannot connect|failed to connect",
        "connection_lost": r"connection.*(?:reset|closed|broken)|network.*unreachable",
        "authentication": r"unauthori[sz]ed|authentication|invalid.auth|forbidden",
        "missing_dependency": r"no module named|modulenotfounderror|importerror|cannot import name",
        "bluetooth": r"org\.bluez|bluetooth|dbus", "setup_retry": r"not ready yet|setup_retry",
        "setup_error": r"error setting up|setup failed|setup_error",
        "delivery_error": r"email delivery:|receiver rejected pending transition",
        "service_reload": r"\bReload(?:ing|ed)\b",
        "service_start": r"\bStart(?:ing|ed)\b",
        "service_stop": r"\bStopp?(?:ing|ed)\b|Deactivated successfully",
        "process_exit": r"Main process exited|Failed with result|Scheduled restart job",
        "oom": r"out of memory|oom.kill|killed process",
    }
    kernel = subprocess.run(
        ["journalctl", "-k", "--since", since.isoformat(), "--until", now.isoformat(),
         "--all", "-o", "json", "--no-pager"],
        check=True, capture_output=True, text=True, timeout=20,
    )
    for line in (records.stdout + kernel.stdout).splitlines():
        record = json.loads(line)
        unit = record.get("UNIT", record.get("_SYSTEMD_UNIT"))
        is_kernel = record.get("_TRANSPORT") == "kernel"
        if is_kernel:
            unit = "kernel"
        if unit not in {"home-assistant.service", "gatus.service", "gatus-email.service",
                        "nixos-upgrade.service", "systemd-oomd.service", "kernel"}:
            continue
        retained[unit] += 1
        message = record.get("MESSAGE", "")
        if isinstance(message, list) and all(type(byte) is int and 0 <= byte <= 255 for byte in message):
            message = bytes(message).decode("utf-8", errors="replace")
        if not isinstance(message, str):
            nontext += 1
            continue
        categories = [code for code, pattern in signatures.items() if re.search(pattern, message, re.I)
                      and (not is_kernel or code == "oom")
                      and (not code.startswith("service_") or record.get("_PID") == "1")]
        if not categories:
            continue
        events.append({
            "observed_at": datetime.fromtimestamp(int(record["__REALTIME_TIMESTAMP"]) / 1_000_000, UTC).isoformat(),
            "unit": unit, "categories": categories,
            "component_domains": sorted(set(re.findall(r"homeassistant\.components\.([a-z0-9_]+)", message))),
            "exception_classes": sorted(set(re.findall(r"\b([A-Za-z]+(?:Error|Exception))\b", message))),
        })
    result["journal"] = {"retained_records": dict(retained), "nontext_omissions": nontext,
                         "matched_records": len(events), "events": events[-300:],
                         "events_not_exported": max(0, len(events) - 300),
                         "coverage": "Categorized retained messages only; raw reasons, addresses, titles and credentials never exported. No matching event is not proof of health."}
    return result


def inspect(args):
    if args.action == "setup":
        if not args.token_file.read_text().strip():
            raise ValueError("Missing HA credential")
        with urlopen(args.gatus_url + "/health", timeout=10) as response:
            if response.status != 200:
                raise ValueError("Gatus unavailable")
        args.ready_file.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        args.ready_file.touch(mode=0o644)
        return {"backend": "gatus", "provisioned": True}

    cutoff = datetime.now(UTC) - timedelta(hours=args.since_hours)
    endpoint = fetch(args.gatus_url + ENDPOINT)
    probes = sorted(
        ({key: probe[key] for key in ("timestamp", "success")} for probe in endpoint["results"]),
        key=lambda probe: probe["timestamp"],
    )
    journal = subprocess.run(
        ["journalctl", "-u", "hass-health.service", "--since", (cutoff - timedelta(seconds=MAX_AGE)).isoformat(), "-o", "cat", "--no-pager"],
        check=True, capture_output=True, text=True, timeout=20,
    )
    reports, samples = [], []
    for line in journal.stdout.splitlines():
        if not line.startswith("{"):
            continue
        item = json.loads(line)
        if item.get("schema_version") != 1 or "observed_at" not in item:
            continue
        if item.get("kind") == "ha_monitor_sample":
            samples.append(item)
        elif "checks" in item and "status" in item:
            reports.append(item)
    reports.sort(key=lambda item: item["observed_at"])
    samples.sort(key=lambda item: item["observed_at"])
    recent_reports = [item for item in reports if timestamp(item["observed_at"]) >= cutoff]
    entity_failures = [
        {"observed_at": item["observed_at"], "entity_id": failure["entity_id"], "state": failure["state"]}
        for item in recent_reports
        for failure in item["checks"].get("critical_entities", {}).get("failures", [])
        if failure.get("entity_id") in CRITICAL_ENTITIES and failure.get("state") in {"missing", "unknown", "unavailable"}
    ]
    alert_journal = subprocess.run(
        ["journalctl", "-u", "gatus-email.service", "-u", "gatus.service", "--since", cutoff.isoformat(), "-o", "json", "--no-pager"],
        check=True, capture_output=True, text=True, timeout=20,
    )
    alert_records = Counter()
    alert_errors = []
    for line in alert_journal.stdout.splitlines():
        record = json.loads(line)
        unit = record.get("_SYSTEMD_UNIT")
        if unit not in {"gatus-email.service", "gatus.service"}:
            continue
        alert_records[unit] += 1
        message = record.get("MESSAGE", "")
        if not isinstance(message, str):
            continue
        category = None
        if unit == "gatus-email.service" and message.startswith("Email delivery: "):
            error = message.removeprefix("Email delivery: ")
            category = error if re.fullmatch(r"email-http-[0-9]{3}|email-network-or-response|email-invalid-receipt", error) else "unclassified_email_error"
        elif unit == "gatus.service" and "Receiver rejected pending transition" in message and "endpoint=smart-home_home-assistant-runtime route=gatus-email" in message:
            category = "producer_receiver_rejected"
        if category:
            alert_errors.append({
                "observed_at": datetime.fromtimestamp(int(record["__REALTIME_TIMESTAMP"]) / 1_000_000, UTC).isoformat(),
                "category": category,
            })
    probes_in_window = [probe for probe in probes if timestamp(probe["timestamp"]) >= cutoff]
    correlation = Counter()
    observed_samples = set()
    for probe in probes_in_window:
        preceding = [item for item in samples if 0 <= (timestamp(probe["timestamp"]) - timestamp(item["observed_at"])).total_seconds() <= MAX_AGE]
        state = "stale_or_missing_sample"
        if preceding:
            sample = preceding[-1]
            observed_samples.add(sample["observed_at"])
            matching = [item for item in reports if 0 <= (timestamp(sample["observed_at"]) - timestamp(item["observed_at"])).total_seconds() <= 90]
            if sample["service_result"] in ("timeout", "signal", "core-dump", "resources"):
                state = sample["service_result"]
            else:
                state = matching[-1]["status"] if matching else "no_ha_report"
        correlation[f"{'success' if probe['success'] else 'failure'}_{state}"] += 1
    recent_samples = [item for item in samples if timestamp(item["observed_at"]) >= cutoff]
    failed_samples = [item for item in recent_samples if not item["success"]]
    fresh_cutoff = datetime.now(UTC) - timedelta(seconds=MAX_AGE)
    active = lambda unit: subprocess.run(["systemctl", "is-active", "--quiet", unit], check=False, timeout=10).returncode == 0
    try:
        try:
            response = urlopen(f"http://127.0.0.1:{args.port}/health", timeout=10)
        except HTTPError as error:
            response = error
        with response:
            served_status = json.load(response).get("status")
            local_http = {
                "http_status": response.status,
                "status": served_status if served_status in ("healthy", "unhealthy", "unknown") else "invalid",
            }
    except (OSError, ValueError, TypeError, AttributeError) as error:
        local_http = {"error_type": type(error).__name__}
    observed_at = datetime.now(UTC)
    probe_times = [timestamp(probe["timestamp"]) for probe in probes_in_window]
    gaps = [(after - before).total_seconds() for before, after in zip(probe_times, probe_times[1:])]
    leading_gap = (probe_times[0] - cutoff).total_seconds() if probe_times else None
    trailing_gap = (observed_at - probe_times[-1]).total_seconds() if probe_times else None
    return {
        "observed_at": observed_at.isoformat(),
        "backend": "gatus",
        "provisioned": args.ready_file.is_file(),
        "timer_active": active("hass-health.timer"),
        "status_server_active": active("hass-health-http.service"),
        "local_status": read_status(args.status_file),
        "local_http": local_http,
        "isolated_status_directory": args.status_file.resolve().is_relative_to("/run/private"),
        "probes": probes_in_window,
        "events": [{key: event[key] for key in ("timestamp", "type")} for event in endpoint.get("events", []) if timestamp(event["timestamp"]) >= cutoff],
        "oldest_available_probe": probes[0]["timestamp"] if probes else None,
        "probe_coverage": {
            "since": cutoff.isoformat(),
            "until": observed_at.isoformat(),
            "probes": len(probe_times),
            "complete": bool(probe_times) and 0 <= leading_gap <= 90 and 0 <= trailing_gap <= 90 and all(gap <= 90 for gap in gaps),
            "leading_gap_seconds": leading_gap,
            "trailing_gap_seconds": trailing_gap,
            "longest_gap_seconds": max(gaps, default=None),
            "gaps_over_90_seconds": sum(gap > 90 for gap in gaps),
        },
        "probe_report_correlation": dict(correlation),
        # A failure at the end of the window may not have been probed yet.
        "failed_samples_not_observed": sum(item["observed_at"] not in observed_samples for item in failed_samples),
        "critical_entity_failures": entity_failures[:100],
        "critical_entity_failures_not_exported": max(0, len(entity_failures) - 100),
        "alert_journal": {
            "retained_records": dict(alert_records),
            "errors": alert_errors[:100],
            "errors_not_exported": max(0, len(alert_errors) - 100),
            "provider_receipts": "unavailable: production receiver logs errors, not successful provider receipts; absence of errors is not delivery proof",
        },
        "journal": {
            "reports": len(recent_reports),
            "first_observed_at": recent_reports[0]["observed_at"] if recent_reports else None,
            "statuses": dict(Counter(item["status"] for item in recent_reports)),
            "failing_checks": dict(Counter(name for item in recent_reports for name, check in item["checks"].items() if check["status"] != "healthy")),
            "last_observed_at": recent_reports[-1]["observed_at"] if recent_reports else None,
            "last_status": recent_reports[-1]["status"] if recent_reports else None,
            "samples": len(recent_samples),
            "service_results": dict(Counter(item["service_result"] for item in recent_samples)),
            "fresh_successful_samples": sum(item["success"] and timestamp(item["observed_at"]) >= fresh_cutoff for item in recent_samples),
            "fresh_healthy_reports": sum(item["status"] == "healthy" and timestamp(item["observed_at"]) >= fresh_cutoff for item in recent_reports),
        },
        "coverage": "Gatus probe coverage uses a 90-second gap allowance for the one-minute endpoint; it is not continuous observation. Journal counts cover retained reports only, not guaranteed retention. Physical outcomes, restic freshness, notification configuration and alert delivery are not checked.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "status", "incident", "publish", "serve"))
    parser.add_argument("--gatus-url", default="http://127.0.0.1:8084")
    parser.add_argument("--token-file", type=Path, default=Path("/run/agenix/ha-hermes-token"))
    parser.add_argument("--ready-file", type=Path, default=READY)
    parser.add_argument("--status-file", type=Path, default=STATUS)
    parser.add_argument("--port", type=int, default=8124)
    parser.add_argument("--since-hours", type=int, choices=range(1, 25), default=2)
    parser.add_argument("--require-live", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "serve":
            serve(args)
            return 0
        if args.action == "incident":
            result = incident_diagnostics()
        else:
            result = publish(args) if args.action == "publish" else inspect(args)
        print(json.dumps(result, sort_keys=True))
        if args.require_live:
            cutoff = datetime.now(UTC) - timedelta(minutes=5)
            return 0 if (
                args.action == "status"
                and result["provisioned"]
                and result["timer_active"]
                and result["status_server_active"]
                and result["local_status"]["status"] == "healthy"
                and result["local_http"] == {"http_status": 200, "status": "healthy"}
                and len(result["probes"]) >= 2
                and all(probe["success"] and timestamp(probe["timestamp"]) >= cutoff for probe in result["probes"][-2:])
                and result["journal"]["fresh_successful_samples"] >= 2
                and result["journal"]["fresh_healthy_reports"] >= 2
                and result["journal"]["last_status"] == "healthy"
                and timestamp(result["journal"]["last_observed_at"]) >= cutoff
            ) else 1
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        # Never echo response bodies, exception messages, credentials or journal lines.
        if isinstance(error, HTTPError):
            error.close()
        print(json.dumps({"status": "unknown", "error_type": type(error).__name__, "http_status": error.code if isinstance(error, HTTPError) else None}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
