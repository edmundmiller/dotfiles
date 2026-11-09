#!/usr/bin/env python3
"""Publish local HA monitor status and inspect Gatus without exporting HA contents."""

import argparse
from collections import Counter
from datetime import UTC, datetime, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import urlopen

READY = Path("/var/lib/hass-health/nuc-ha-runtime-gatus.ready")
STATUS = Path("/run/hass-health/status.json")
ENDPOINT = "/api/v1/endpoints/smart-home_home-assistant-runtime/statuses?pageSize=1500"
MAX_AGE = 300


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
    except (OSError, ValueError, KeyError, TypeError):
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
    return {
        "observed_at": datetime.now(UTC).isoformat(),
        "backend": "gatus",
        "provisioned": args.ready_file.is_file(),
        "timer_active": active("hass-health.timer"),
        "status_server_active": active("hass-health-http.service"),
        "local_status": read_status(args.status_file),
        "probes": probes_in_window,
        "events": [{key: event[key] for key in ("timestamp", "type")} for event in endpoint.get("events", []) if timestamp(event["timestamp"]) >= cutoff],
        "oldest_available_probe": probes[0]["timestamp"] if probes else None,
        "probe_report_correlation": dict(correlation),
        # A failure at the end of the window may not have been probed yet.
        "failed_samples_not_observed": sum(item["observed_at"] not in observed_samples for item in failed_samples),
        "journal": {
            "reports": len(recent_reports),
            "statuses": dict(Counter(item["status"] for item in recent_reports)),
            "failing_checks": dict(Counter(name for item in recent_reports for name, check in item["checks"].items() if check["status"] != "healthy")),
            "last_observed_at": recent_reports[-1]["observed_at"] if recent_reports else None,
            "last_status": recent_reports[-1]["status"] if recent_reports else None,
            "samples": len(recent_samples),
            "service_results": dict(Counter(item["service_result"] for item in recent_samples)),
            "fresh_successful_samples": sum(item["success"] and timestamp(item["observed_at"]) >= fresh_cutoff for item in recent_samples),
            "fresh_healthy_reports": sum(item["status"] == "healthy" and timestamp(item["observed_at"]) >= fresh_cutoff for item in recent_reports),
        },
        "coverage": "Gatus history and local journal aggregates only. Physical outcomes and restic freshness not checked. No push notification provider is enabled by this monitor.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "status", "publish", "serve"))
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
