#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["websockets>=15,<17"]
# ///
"""Read-only fixed-entity mapping and bounded, categorized journal evidence."""

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

from websockets.sync.client import connect

ENTITY = "climate.master_suite"
# Five-minute margins around the assessment's recovered intervals, merged where overlapping.
WINDOWS = tuple(
    (datetime.fromisoformat(f"2026-11-10T{start}+00:00"),
     datetime.fromisoformat(f"2026-11-10T{end}+00:00"))
    for start, end in (
        ("06:15:00", "06:38:00"), ("08:44:00", "09:09:00"),
        ("09:39:00", "10:03:00"), ("10:42:00", "10:58:00"),
        ("13:43:00", "14:07:00"), ("14:39:00", "15:02:00"),
        ("15:34:00", "15:59:00"),
    )
)
CATEGORIES = (
    ("timeout", r"timed? out|timeout"),
    ("authentication", r"unauthori[sz]ed|forbidden|authentication|invalid.auth|\b40[13]\b"),
    ("rate_limited", r"rate.limit|too many requests|\b429\b"),
    ("connection_failure", r"connection.*(?:refused|reset|closed|failed|broken)|cannot connect|unable to connect|network.*unreachable"),
    ("unavailable", r"unavailable|offline|not responding"),
)


def request(socket, request_id, command, **fields):
    socket.send(json.dumps({"id": request_id, "type": command, **fields}))
    reply = json.loads(socket.recv(timeout=10))
    if (reply.get("id") != request_id or reply.get("type") != "result"
            or not reply.get("success")):
        raise ValueError("Read failed")
    return reply["result"]


def mapping(socket):
    entity = request(socket, 1, "config/entity_registry/get", entity_id=ENTITY)
    platform = entity["platform"]
    entry_id = entity["config_entry_id"]
    if (entity["entity_id"] != ENTITY or not re.fullmatch(r"[a-z0-9_]+", platform)
            or not re.fullmatch(r"[A-Za-z0-9]+", entry_id)):
        raise ValueError("Unsupported mapping")
    entries = request(socket, 2, "config_entries/get")
    entry = next(item for item in entries if item["entry_id"] == entry_id)
    if not re.fullmatch(r"[a-z0-9_]+", entry["domain"]):
        raise ValueError("Unsupported domain")
    state = entry["state"]
    return {
        "entity_id": ENTITY,
        "platform": platform,
        "config_entry_id": entry_id,
        "integration_domain": entry["domain"],
        "integration_state": state if state in {
            "loaded", "not_loaded", "setup_error", "setup_retry", "migration_error",
            "failed_unload", "setup_in_progress", "unload_in_progress",
        } else "other",
        "entity_disabled": entity.get("disabled_by") is not None,
        "integration_disabled": entry.get("disabled_by") is not None,
    }


def journal_summary(text, entity_mapping, windows=WINDOWS, recurrence=False):
    counts = Counter()
    matched_times = []
    window_records = 0
    binary_messages = 0
    decoded_byte_messages = 0
    events = []
    retained_times = []
    checker_reports = []
    checker_times = []
    malformed_checker_reports = 0
    domain = re.escape(entity_mapping["integration_domain"])
    platform = re.escape(entity_mapping["platform"])
    logger = re.compile(r"\[homeassistant\.components\.(?:" + domain + "|" + platform + r")(?:\.[^\]]*)?\]")
    identity = re.compile(
        r"(?<![A-Za-z0-9_.])(?:" + re.escape(ENTITY) + "|"
        + re.escape(entity_mapping["config_entry_id"]) + r")(?![A-Za-z0-9_.])"
    )
    for line in text.splitlines():
        record = json.loads(line)
        observed = datetime.fromtimestamp(int(record["__REALTIME_TIMESTAMP"]) / 1_000_000, timezone.utc)
        if not any(start <= observed <= end for start, end in windows):
            continue
        message = record.get("MESSAGE")
        if isinstance(message, list) and all(
                type(value) is int and 0 <= value <= 255 for value in message):
            try:
                message = bytes(message).decode("utf-8")
                decoded_byte_messages += 1
            except UnicodeDecodeError:
                pass
        if not isinstance(message, str):
            binary_messages += 1
        if recurrence and record.get("_SYSTEMD_UNIT") == "hass-health.service":
            try:
                report = json.loads(message)
                if not isinstance(report, dict):
                    raise ValueError("Unsupported checker report")
                if report.get("schema_version") != 1:
                    continue
                critical = report["checks"]["critical_entities"]
                if critical["status"] not in {"healthy", "unhealthy", "unknown"}:
                    raise ValueError("Unsupported checker status")
                reported_at = utc_time(report["observed_at"])
                if not windows[0][0] <= reported_at <= windows[0][1]:
                    continue
                failures = [failure["state"] for failure in critical.get("failures", [])
                            if failure.get("entity_id") == ENTITY
                            and failure.get("state") in {"missing", "unknown", "unavailable"}]
                checker_times.append(reported_at.isoformat())
                if len(checker_reports) < 100:
                    checker_reports.append({
                        "observed_at": reported_at.isoformat(),
                        "critical_entities_status": critical["status"],
                        "entity_failures": failures,
                    })
            except (ValueError, KeyError, TypeError):
                malformed_checker_reports += 1
            continue
        window_records += 1
        retained_times.append(observed.isoformat())
        if not isinstance(message, str):
            continue
        message = re.sub(r"\x1b\[[0-9;]*m", "", message)
        header = re.match(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:[.,]\d+)? "
            r"(ERROR|WARNING|CRITICAL) \([^\r\n)]+\) (\[[^\r\n\]]+\]) (.*)",
            message, re.S,
        )
        if not header:
            continue
        severity, component, body = header.groups()
        if identity.search(body):
            scope = "entity_or_config_entry"
        elif logger.fullmatch(component):
            scope = "integration_wide_not_entity_specific"
        elif recurrence and re.fullmatch(r"\[aiohomekit(?:\.[A-Za-z0-9_]+)*\]", component):
            scope = "homekit_library_not_entity_specific"
        else:
            continue
        categories = [code for code, pattern in CATEGORIES if re.search(pattern, body, re.I)]
        categories = categories or ["unclassified_warning_or_error"]
        for category in categories:
            counts[scope, category] += 1
        matched_times.append(observed.isoformat())
        if recurrence and len(events) < 100:
            events.append({
                "observed_at": observed.isoformat(),
                "america_chicago": observed.astimezone(ZoneInfo("America/Chicago")).isoformat(),
                "scope": scope, "categories": categories,
                "severity": severity,
                "exception_types": sorted(set(re.findall(
                    r"\b(TimeoutError|ConnectionError|ConnectionResetError|ConnectionRefusedError|"
                    r"AuthenticationError|InvalidAuthError|DisconnectedError|OSError)\b", body))),
            })
    summary = {
        "windows": [{"start": start.isoformat(), "end": end.isoformat()} for start, end in windows],
        "retained_records_in_windows": window_records,
        "decoded_byte_messages": decoded_byte_messages,
        "nontext_messages_not_classified": binary_messages,
        "matched_records": len(matched_times),
        "first_match": min(matched_times) if matched_times else None,
        "last_match": max(matched_times) if matched_times else None,
        "category_counts": [{"scope": scope, "category": category, "count": count}
                            for (scope, category), count in sorted(counts.items())],
        "coverage": "Retained warning/error headers matching the entity/config entry or mapped component logger only. Integration-wide errors are not attributed to this thermostat. Category counts can overlap. Retention is aggregated, not verified for each window. Separate traceback records are not reconstructed and can lose category attribution. Zero matches do not prove absence of errors or journal retention.",
    }
    if recurrence:
        summary.update({
            "retention_by_window": [{
                "start": windows[0][0].isoformat(), "end": windows[0][1].isoformat(),
                "retained_ha_records": window_records,
                "first_retained_ha_record": min(retained_times) if retained_times else None,
                "last_retained_ha_record": max(retained_times) if retained_times else None,
                "matched_records": len(matched_times),
                "checker_reports": len(checker_times),
                "first_retained_checker_report": min(checker_times, default=None),
                "last_retained_checker_report": max(checker_times, default=None),
            }],
            "events": events, "matching_events_not_exported": len(matched_times) - len(events),
            "checker_reports": checker_reports,
            "checker_reports_not_exported": len(checker_times) - len(checker_reports),
            "malformed_checker_records_not_classified": malformed_checker_reports,
            "coverage": "One bounded retained journal window, not continuous retention proof. Entity/config-entry text matches, mapped-component and aiohomekit-library evidence have separate scopes; neither integration nor library scope proves this device failed. Counts can overlap. Only traceback text inside the same MESSAGE is classified; separate continuation records are not associated and may lose exception/category evidence. Zero matches do not prove absent errors. Checker reports are retained samples, not continuous state; an empty entity_failures list is not a state observation. Gatus/incident timing must come from existing evidence, not this reader. No assessment rescoring.",
        })
    return summary


def utc_time(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.utcoffset() != timedelta(0):
        raise ValueError("Explicit UTC timestamp required")
    return parsed.astimezone(timezone.utc)


def incident_window(start, cutoff, recovered, now):
    start, cutoff = utc_time(start), utc_time(cutoff)
    recovery = utc_time(recovered) if recovered else None
    if not start <= cutoff <= now or (recovery is not None and not start <= recovery <= cutoff):
        raise ValueError("Invalid incident bounds")
    lead = start - timedelta(minutes=5)
    requested_end = min(cutoff, recovery + timedelta(minutes=5)) if recovery else cutoff
    end = min(requested_end, lead + timedelta(minutes=30))
    return ((lead, end),), {
        "incident_start": start.isoformat(), "capture_cutoff": cutoff.isoformat(),
        "reported_recovery": recovery.isoformat() if recovery else None,
        "recovery_status": "reported_not_independently_verified" if recovery else "unrecovered_at_cutoff_as_reported",
        "window_start": lead.isoformat(), "window_end": end.isoformat(),
        "america_chicago_start": lead.astimezone(ZoneInfo("America/Chicago")).isoformat(),
        "america_chicago_end": end.astimezone(ZoneInfo("America/Chicago")).isoformat(),
        "truncated_at_30_minutes": end < requested_end,
        "full_recovery_margin_included": recovery is not None and end >= recovery + timedelta(minutes=5),
        "bounds_source": "Caller-supplied human/checker incident evidence; not inferred from aggregate failures",
    }


def current_state(token):
    with urlopen(Request("http://127.0.0.1:8123/api/states/" + ENTITY,
                         headers={"Authorization": "Bearer " + token}), timeout=10) as response:
        state = json.load(response)
    if state["entity_id"] != ENTITY:
        raise ValueError("Unexpected entity")
    return {
        "entity_id": ENTITY,
        "state": state["state"] if state["state"] in {
            "unavailable", "unknown", "off", "heat", "cool", "heat_cool", "auto", "dry", "fan_only",
        } else "other",
        "last_changed": utc_time(state["last_changed"]).isoformat(),
        "last_updated": utc_time(state["last_updated"]).isoformat(),
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "coverage": "Current snapshot only, not state or mapping during an earlier incident. Device maker/model and endpoint association are not exported or established.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--incident-start")
    parser.add_argument("--incident-cutoff")
    parser.add_argument("--recovered-at", default="")
    args = parser.parse_args()
    recurrence = any((args.incident_start, args.incident_cutoff, args.recovered_at))
    if recurrence and not (args.incident_start and args.incident_cutoff):
        raise ValueError("Both incident bounds required")
    windows, incident = (incident_window(args.incident_start, args.incident_cutoff,
                                        args.recovered_at, datetime.now(timezone.utc))
                         if recurrence else (WINDOWS, None))
    token = Path("/run/agenix/ha-hermes-token").read_text().strip()
    with connect("ws://127.0.0.1:8123/api/websocket", open_timeout=10,
                 close_timeout=1, max_size=16 * 1024 * 1024, proxy=None) as socket:
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_required":
            raise ValueError("Unexpected handshake")
        socket.send(json.dumps({"type": "auth", "access_token": token}))
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_ok":
            raise ValueError("Authentication failed")
        entity_mapping = mapping(socket)
    state = None
    if recurrence:
        try:
            state = current_state(token)
        except (OSError, ValueError, KeyError, TypeError) as error:
            state = {"status": "unknown", "error_type": type(error).__name__}
    try:
        units = ["-u", "home-assistant.service"]
        if recurrence:
            units += ["-u", "hass-health.service"]
        timestamp_format = "%Y-%m-%d %H:%M:%S.%f UTC" if recurrence else "%Y-%m-%d %H:%M:%S UTC"
        journal = subprocess.run(
            ["journalctl", *units, "--since", windows[0][0].strftime(timestamp_format),
             "--until", windows[-1][1].strftime(timestamp_format), "-o", "json", "--no-pager"],
            capture_output=True, text=True, check=True, timeout=20,
        )
        summary = journal_summary(journal.stdout, entity_mapping, windows, recurrence)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        summary = {"status": "unknown", "error_type": type(error).__name__}
    result = {
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "mapping": entity_mapping, "journal": summary,
        "omitted": ["titles", "unique_ids", "device_ids", "attributes", "options", "credentials", "addresses", "raw_messages", "free_form_errors"],
    }
    if recurrence:
        result.update({"incident": incident, "current_state": state, "transport_metadata": {
            "association": "unknown", "collected": False,
            "reason": "No verified entity-to-endpoint association; no socket, route, neighbor reads or active probes",
        }})
    print(json.dumps(result, sort_keys=True))
    return 0 if summary.get("retained_records_in_windows") and (not recurrence or state.get("status") != "unknown") else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps({"status": "unknown", "error_type": type(error).__name__}))
        sys.exit(2)
